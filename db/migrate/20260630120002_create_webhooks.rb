class CreateWebhooks < ActiveRecord::Migration[7.2]
  def change
    # Outbound: record of each delivery attempt to an external endpoint.
    create_table :webhook_deliveries, id: :uuid do |t|
      t.references :credit_application, type: :uuid, null: false, foreign_key: true
      t.string :endpoint, null: false
      t.string :status, null: false, default: "pending" # pending / delivered / failed
      t.integer :attempts, null: false, default: 0
      t.jsonb :last_response

      t.timestamps
    end

    # Inbound: dedupe ledger for received webhooks (idempotency_key unique).
    create_table :webhook_events, id: :uuid do |t|
      t.string :idempotency_key, null: false
      t.string :source, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end
    add_index :webhook_events, :idempotency_key, unique: true
  end
end
