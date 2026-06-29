class CreateCreditApplications < ActiveRecord::Migration[7.2]
  def change
    create_table :credit_applications, id: :uuid do |t|
      t.string :country, null: false

      # PII at rest — stored as ciphertext (Active Record encryption), hence text.
      t.text :full_name, null: false       # non-deterministic
      t.text :document_number, null: false # deterministic (searchable / dedupe)
      t.text :monthly_income, null: false  # non-deterministic

      t.string :document_type, null: false
      # Blind index: keyed HMAC of the document number for unique dedupe lookups
      # without decrypting.
      t.string :document_fingerprint, null: false

      t.decimal :amount_requested, precision: 15, scale: 2, null: false
      t.datetime :requested_at

      t.string :status, null: false, default: "received" # managed by AASM (M2)
      t.integer :risk_score                              # filled by async job (M2)
      t.jsonb :flags, null: false, default: {}
      t.integer :lock_version, null: false, default: 0   # optimistic locking

      t.timestamps
    end

    # Critical listing query: filter by country + status, ordered by recency.
    add_index :credit_applications, [ :country, :status, :created_at ]
    # Dedupe / lookup by document without decrypting.
    add_index :credit_applications, :document_fingerprint, unique: true
  end
end
