class CreateBankRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :bank_records, id: :uuid do |t|
      t.references :credit_application, type: :uuid, null: false, foreign_key: true

      t.string :provider, null: false
      # Normalized (internal) shape produced by the per-country Normalizer.
      t.decimal :total_debt, precision: 15, scale: 2
      t.integer :credit_score
      t.string :account_status
      # Raw provider response kept for audit / decoupling from provider shape.
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :fetched_at

      t.timestamps
    end
  end
end
