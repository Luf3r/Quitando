class CreatePaymentCommandReceipts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    with_lock_timeout do
      create_table :payment_command_receipts, id: :uuid, default: -> { "uuidv7()" } do |t|
        t.uuid :payment_id, null: false
        t.string :command_type, null: false
        t.uuid :idempotency_key, null: false
        t.string :request_fingerprint, null: false
        t.timestamps
      end
      add_check_constraint :payment_command_receipts, "command_type IN ('report', 'confirm', 'cancel')", name: "payment_command_receipts_command_type_valid"
      add_foreign_key :payment_command_receipts, :payments, validate: false
      validate_foreign_key :payment_command_receipts, :payments
      add_index :payment_command_receipts, :idempotency_key, unique: true, algorithm: :concurrently
      add_index :payment_command_receipts, %i[payment_id command_type], unique: true, algorithm: :concurrently

      create_append_only_guard
      backfill_report_receipts
      validate_report_receipt_coverage
      remove_index :payments, :idempotency_key, algorithm: :concurrently
      add_index :payments, :idempotency_key, algorithm: :concurrently
    end
  end

  def down
    with_lock_timeout do
      remove_index :payments, :idempotency_key, algorithm: :concurrently
      add_index :payments, :idempotency_key, unique: true, algorithm: :concurrently
      execute "DROP TRIGGER IF EXISTS payment_command_receipts_append_only ON payment_command_receipts"
      execute "DROP FUNCTION IF EXISTS prevent_payment_command_receipt_mutation()"
      remove_index :payment_command_receipts, %i[payment_id command_type], algorithm: :concurrently
      remove_index :payment_command_receipts, :idempotency_key, algorithm: :concurrently
      drop_table :payment_command_receipts
    end
  end

  private

  def with_lock_timeout
    previous_lock_timeout = connection.select_value("SHOW lock_timeout")
    execute "SET lock_timeout = '2s'"
    yield
  ensure
    execute "SET lock_timeout = #{connection.quote(previous_lock_timeout)}" if previous_lock_timeout
  end

  def create_append_only_guard
    execute <<~SQL
      CREATE FUNCTION prevent_payment_command_receipt_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'payment command receipts are append-only'
          USING ERRCODE = '55000';
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER payment_command_receipts_append_only
      BEFORE UPDATE OR DELETE ON payment_command_receipts
      FOR EACH ROW EXECUTE FUNCTION prevent_payment_command_receipt_mutation()
    SQL
  end

  def backfill_report_receipts
    execute <<~SQL
      INSERT INTO payment_command_receipts (
        id, payment_id, command_type, idempotency_key, request_fingerprint, created_at, updated_at
      )
      SELECT uuidv7(), id, 'report', idempotency_key, request_fingerprint, created_at, updated_at
      FROM payments
    SQL
  end

  def validate_report_receipt_coverage
    execute <<~SQL
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM payments
          WHERE NOT EXISTS (
            SELECT 1
            FROM payment_command_receipts
            WHERE payment_command_receipts.payment_id = payments.id
              AND payment_command_receipts.command_type = 'report'
          )
        ) THEN
          RAISE EXCEPTION 'payment report receipt backfill is incomplete'
            USING ERRCODE = '23514';
        END IF;
      END;
      $$
    SQL
  end
end
