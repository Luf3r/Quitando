class CreateFinancialEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :group, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :role, null: false
      t.string :status, null: false
      t.timestamps
    end
    add_index :memberships, %i[group_id user_id], unique: true
    add_check_constraint :memberships, "role IN ('owner', 'member')", name: "memberships_role_valid"
    add_check_constraint :memberships, "status IN ('active', 'inactive')", name: "memberships_status_valid"

    create_table :expenses, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :group, null: false, type: :uuid, foreign_key: true
      t.references :paid_by_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :created_by_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.bigint :amount_cents, null: false
      t.string :description, null: false
      t.date :occurred_on, null: false
      t.datetime :voided_at
      t.references :voided_by_user, type: :uuid, foreign_key: { to_table: :users }
      t.string :void_reason
      t.references :replaces_expense, type: :uuid, foreign_key: { to_table: :expenses }
      t.timestamps
    end
    add_check_constraint :expenses, "amount_cents > 0", name: "expenses_amount_positive"
    add_check_constraint :expenses, "(voided_at IS NULL AND voided_by_user_id IS NULL AND void_reason IS NULL) OR (voided_at IS NOT NULL AND voided_by_user_id IS NOT NULL AND void_reason IS NOT NULL)", name: "expenses_void_metadata_complete"
    add_check_constraint :expenses, "replaces_expense_id IS NULL OR replaces_expense_id <> id", name: "expenses_no_self_replacement"

    create_table :expense_shares, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :expense, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.bigint :amount_owed_cents, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :expense_shares, %i[expense_id user_id], unique: true
    add_check_constraint :expense_shares, "amount_owed_cents > 0", name: "expense_shares_amount_positive"

    create_table :payments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :group, null: false, type: :uuid, foreign_key: true
      t.references :from_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :to_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.bigint :amount_cents, null: false
      t.string :status, null: false
      t.uuid :idempotency_key, null: false
      t.string :request_fingerprint, null: false
      t.bigint :source_financial_state_version, null: false
      t.references :reported_by_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :reported_at, null: false
      t.references :confirmed_by_user, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.references :cancelled_by_user, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :cancelled_at
      t.string :cancellation_reason
      t.timestamps
    end
    add_index :payments, :idempotency_key, unique: true
    add_index :payments, %i[group_id status]
    add_index :payments, :reported_at
    add_index :payments, :confirmed_at
    add_check_constraint :payments, "amount_cents > 0", name: "payments_amount_positive"
    add_check_constraint :payments, "from_user_id <> to_user_id", name: "payments_distinct_participants"
    add_check_constraint :payments, "source_financial_state_version >= 0", name: "payments_source_version_nonnegative"
    add_check_constraint :payments, "status IN ('reported', 'confirmed', 'cancelled')", name: "payments_status_valid"
    add_check_constraint :payments, "(status = 'reported' AND confirmed_by_user_id IS NULL AND confirmed_at IS NULL AND cancelled_by_user_id IS NULL AND cancelled_at IS NULL AND cancellation_reason IS NULL) OR (status = 'confirmed' AND confirmed_by_user_id IS NOT NULL AND confirmed_at IS NOT NULL AND cancelled_by_user_id IS NULL AND cancelled_at IS NULL AND cancellation_reason IS NULL) OR (status = 'cancelled' AND confirmed_by_user_id IS NULL AND confirmed_at IS NULL AND cancelled_by_user_id IS NOT NULL AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL)", name: "payments_audit_metadata_matches_status"
  end
end
