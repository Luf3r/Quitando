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

ActiveRecord::Schema[8.1].define(version: 2026_07_21_165000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "expense_shares", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "amount_owed_cents", null: false
    t.datetime "created_at", null: false
    t.uuid "expense_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["expense_id", "user_id"], name: "index_expense_shares_on_expense_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_expense_shares_on_user_id"
    t.check_constraint "amount_owed_cents > 0", name: "expense_shares_amount_positive"
  end

  create_table "expenses", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_user_id", null: false
    t.string "description", null: false
    t.uuid "group_id", null: false
    t.date "occurred_on", null: false
    t.uuid "paid_by_user_id", null: false
    t.uuid "replaces_expense_id"
    t.datetime "updated_at", null: false
    t.string "void_reason"
    t.datetime "voided_at"
    t.uuid "voided_by_user_id"
    t.index ["created_by_user_id"], name: "index_expenses_on_created_by_user_id"
    t.index ["group_id"], name: "index_expenses_on_group_id"
    t.index ["paid_by_user_id"], name: "index_expenses_on_paid_by_user_id"
    t.index ["replaces_expense_id"], name: "index_expenses_on_replaces_expense_id"
    t.index ["voided_by_user_id"], name: "index_expenses_on_voided_by_user_id"
    t.check_constraint "amount_cents > 0", name: "expenses_amount_positive"
    t.check_constraint "replaces_expense_id IS NULL OR replaces_expense_id <> id", name: "expenses_no_self_replacement"
    t.check_constraint "voided_at IS NULL AND voided_by_user_id IS NULL AND void_reason IS NULL OR voided_at IS NOT NULL AND voided_by_user_id IS NOT NULL AND void_reason IS NOT NULL", name: "expenses_void_metadata_complete"
  end

  create_table "groups", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "currency_code", null: false
    t.bigint "financial_state_version", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "financial_state_version >= 0", name: "groups_financial_state_version_nonnegative"
  end

  create_table "memberships", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "group_id", null: false
    t.string "role", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["group_id", "user_id"], name: "index_memberships_on_group_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'member'::character varying]::text[])", name: "memberships_role_valid"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "memberships_status_valid"
  end

  create_table "payments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.string "cancellation_reason"
    t.datetime "cancelled_at"
    t.uuid "cancelled_by_user_id"
    t.datetime "confirmed_at"
    t.uuid "confirmed_by_user_id"
    t.datetime "created_at", null: false
    t.uuid "from_user_id", null: false
    t.uuid "group_id", null: false
    t.uuid "idempotency_key", null: false
    t.datetime "reported_at", null: false
    t.uuid "reported_by_user_id", null: false
    t.string "request_fingerprint", null: false
    t.bigint "source_financial_state_version", null: false
    t.string "status", null: false
    t.uuid "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cancelled_by_user_id"], name: "index_payments_on_cancelled_by_user_id"
    t.index ["confirmed_at"], name: "index_payments_on_confirmed_at"
    t.index ["confirmed_by_user_id"], name: "index_payments_on_confirmed_by_user_id"
    t.index ["from_user_id"], name: "index_payments_on_from_user_id"
    t.index ["group_id", "status"], name: "index_payments_on_group_id_and_status"
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true
    t.index ["reported_at"], name: "index_payments_on_reported_at"
    t.index ["reported_by_user_id"], name: "index_payments_on_reported_by_user_id"
    t.index ["to_user_id"], name: "index_payments_on_to_user_id"
    t.check_constraint "amount_cents > 0", name: "payments_amount_positive"
    t.check_constraint "from_user_id <> to_user_id", name: "payments_distinct_participants"
    t.check_constraint "source_financial_state_version >= 0", name: "payments_source_version_nonnegative"
    t.check_constraint "status::text = 'reported'::text AND confirmed_by_user_id IS NULL AND confirmed_at IS NULL AND cancelled_by_user_id IS NULL AND cancelled_at IS NULL AND cancellation_reason IS NULL OR status::text = 'confirmed'::text AND confirmed_by_user_id IS NOT NULL AND confirmed_at IS NOT NULL AND cancelled_by_user_id IS NULL AND cancelled_at IS NULL AND cancellation_reason IS NULL OR status::text = 'cancelled'::text AND confirmed_by_user_id IS NULL AND confirmed_at IS NULL AND cancelled_by_user_id IS NOT NULL AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL", name: "payments_audit_metadata_matches_status"
    t.check_constraint "status::text = ANY (ARRAY['reported'::character varying, 'confirmed'::character varying, 'cancelled'::character varying]::text[])", name: "payments_status_valid"
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "expense_shares", "expenses"
  add_foreign_key "expense_shares", "users"
  add_foreign_key "expenses", "expenses", column: "replaces_expense_id"
  add_foreign_key "expenses", "groups"
  add_foreign_key "expenses", "users", column: "created_by_user_id"
  add_foreign_key "expenses", "users", column: "paid_by_user_id"
  add_foreign_key "expenses", "users", column: "voided_by_user_id"
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "payments", "groups"
  add_foreign_key "payments", "users", column: "cancelled_by_user_id"
  add_foreign_key "payments", "users", column: "confirmed_by_user_id"
  add_foreign_key "payments", "users", column: "from_user_id"
  add_foreign_key "payments", "users", column: "reported_by_user_id"
  add_foreign_key "payments", "users", column: "to_user_id"
end
