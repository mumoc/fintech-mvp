class CreateOutboxAndAuditTriggers < ActiveRecord::Migration[7.2]
  def up
    create_table :outbox_events, id: :uuid do |t|
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    # Dispatchers only scan unprocessed rows, oldest first.
    add_index :outbox_events, :created_at,
              where: "processed_at IS NULL",
              name: "index_outbox_events_unprocessed"
    add_index :outbox_events, [ :aggregate_type, :aggregate_id ]

    create_table :audit_logs, id: :uuid do |t|
      t.string :table_name, null: false
      t.uuid :record_id, null: false
      t.string :action, null: false
      t.jsonb :old_data
      t.jsonb :new_data
      t.datetime :changed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :audit_logs, [ :table_name, :record_id ]

    # Outbox: emit exactly one event per create / status change, in the SAME
    # transaction as the row change. PII is never placed in the payload.
    execute <<~SQL
      CREATE FUNCTION enqueue_outbox_event() RETURNS trigger AS $$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
          INSERT INTO outbox_events (id, aggregate_type, aggregate_id, event_type, payload, created_at)
          VALUES (gen_random_uuid(), TG_ARGV[0], NEW.id, 'created',
                  jsonb_build_object('status', NEW.status, 'country', NEW.country), now());
        ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
          INSERT INTO outbox_events (id, aggregate_type, aggregate_id, event_type, payload, created_at)
          VALUES (gen_random_uuid(), TG_ARGV[0], NEW.id, 'status_changed',
                  jsonb_build_object('from', OLD.status, 'to', NEW.status, 'country', NEW.country), now());
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER credit_applications_outbox
      AFTER INSERT OR UPDATE ON credit_applications
      FOR EACH ROW EXECUTE FUNCTION enqueue_outbox_event('CreditApplication');
    SQL

    # Generic audit: capture the old/new row image (ciphertext for encrypted
    # columns, so no plaintext PII is stored) for every change.
    execute <<~SQL
      CREATE FUNCTION write_audit_log() RETURNS trigger AS $$
      DECLARE
        rec_id uuid;
      BEGIN
        IF (TG_OP = 'DELETE') THEN
          rec_id := OLD.id;
        ELSE
          rec_id := NEW.id;
        END IF;

        INSERT INTO audit_logs (id, table_name, record_id, action, old_data, new_data, changed_at)
        VALUES (
          gen_random_uuid(), TG_TABLE_NAME, rec_id, TG_OP,
          CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
          CASE WHEN TG_OP IN ('UPDATE', 'INSERT') THEN to_jsonb(NEW) ELSE NULL END,
          now()
        );
        RETURN COALESCE(NEW, OLD);
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER credit_applications_audit
      AFTER INSERT OR UPDATE OR DELETE ON credit_applications
      FOR EACH ROW EXECUTE FUNCTION write_audit_log();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS credit_applications_audit ON credit_applications;"
    execute "DROP TRIGGER IF EXISTS credit_applications_outbox ON credit_applications;"
    execute "DROP FUNCTION IF EXISTS write_audit_log();"
    execute "DROP FUNCTION IF EXISTS enqueue_outbox_event();"
    drop_table :audit_logs
    drop_table :outbox_events
  end
end
