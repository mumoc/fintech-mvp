class CreateStateTransitions < ActiveRecord::Migration[7.2]
  def change
    create_table :state_transitions, id: :uuid do |t|
      t.references :credit_application, type: :uuid, null: false, foreign_key: true

      t.string :from_state
      t.string :to_state, null: false
      # System-initiated transitions have no actor.
      t.references :actor, type: :uuid, null: true, foreign_key: { to_table: :users }
      t.string :reason
      t.jsonb :metadata, null: false, default: {}

      # Append-only history: created_at only (no updated_at).
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :state_transitions, [ :credit_application_id, :created_at ]
  end
end
