# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_06_29_120005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "bank_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "credit_application_id", null: false
    t.string "provider", null: false
    t.decimal "total_debt", precision: 15, scale: 2
    t.integer "credit_score"
    t.string "account_status"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_application_id"], name: "index_bank_records_on_credit_application_id"
  end

  create_table "credit_applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country", null: false
    t.text "full_name", null: false
    t.text "document_number", null: false
    t.text "monthly_income", null: false
    t.string "document_type", null: false
    t.string "document_fingerprint", null: false
    t.decimal "amount_requested", precision: 15, scale: 2, null: false
    t.datetime "requested_at"
    t.string "status", default: "received", null: false
    t.integer "risk_score"
    t.jsonb "flags", default: {}, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country", "status", "created_at"], name: "index_credit_applications_on_country_and_status_and_created_at"
    t.index ["document_fingerprint"], name: "index_credit_applications_on_document_fingerprint", unique: true
  end

  create_table "state_transitions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "credit_application_id", null: false
    t.string "from_state"
    t.string "to_state", null: false
    t.uuid "actor_id"
    t.string "reason"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["actor_id"], name: "index_state_transitions_on_actor_id"
    t.index ["credit_application_id", "created_at"], name: "idx_on_credit_application_id_created_at_3f4bcfd81e"
    t.index ["credit_application_id"], name: "index_state_transitions_on_credit_application_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "bank_records", "credit_applications"
  add_foreign_key "state_transitions", "credit_applications"
  add_foreign_key "state_transitions", "users", column: "actor_id"
end
