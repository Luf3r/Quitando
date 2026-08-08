class UnifyFinancialCommandReceiptsAndProtectExpenseHistory < ActiveRecord::Migration[8.1]
  def up
    with_lock_timeout do
      rename_table :payment_command_receipts, :financial_command_receipts if table_exists?(:payment_command_receipts) && !table_exists?(:financial_command_receipts)
      change_column_null :financial_command_receipts, :payment_id, true
      add_reference :financial_command_receipts, :expense, type: :uuid, foreign_key: false, index: false unless column_exists?(:financial_command_receipts, :expense_id)
      unless foreign_key_exists?(:financial_command_receipts, :expenses, column: :expense_id)
        add_foreign_key :financial_command_receipts, :expenses, column: :expense_id, validate: false
        validate_foreign_key :financial_command_receipts, :expenses, column: :expense_id
      end
      remove_check_constraint :financial_command_receipts, name: "payment_command_receipts_command_type_valid" if check_constraint_exists?(:financial_command_receipts, name: "payment_command_receipts_command_type_valid")
      add_check_constraint :financial_command_receipts, <<~SQL.squish, name: "financial_command_receipts_result_matches_type" unless check_constraint_exists?(:financial_command_receipts, name: "financial_command_receipts_result_matches_type")
        (command_type IN ('report', 'confirm', 'cancel') AND payment_id IS NOT NULL AND expense_id IS NULL)
        OR (command_type = 'expense_correct' AND payment_id IS NULL AND expense_id IS NOT NULL)
      SQL
      remove_index :financial_command_receipts, name: "idx_on_payment_id_command_type_ba075977fe"
      remove_index :financial_command_receipts, name: "index_financial_command_receipts_on_expense_id" if index_exists?(:financial_command_receipts, :expense_id, name: "index_financial_command_receipts_on_expense_id")
      add_index :financial_command_receipts, %i[payment_id command_type], unique: true, where: "payment_id IS NOT NULL", name: "index_financial_receipts_on_payment_and_type" unless index_exists?(:financial_command_receipts, %i[payment_id command_type], name: "index_financial_receipts_on_payment_and_type")
      add_index :financial_command_receipts, %i[expense_id command_type], unique: true, where: "expense_id IS NOT NULL", name: "index_financial_receipts_on_expense_and_type" unless index_exists?(:financial_command_receipts, %i[expense_id command_type], name: "index_financial_receipts_on_expense_and_type")
      remove_index :expenses, name: "index_expenses_on_replaces_expense_id" if index_exists?(:expenses, :replaces_expense_id, name: "index_expenses_on_replaces_expense_id")
      add_index :expenses, :replaces_expense_id, unique: true, where: "replaces_expense_id IS NOT NULL", name: "index_expenses_on_replaces_expense_id_unique" unless index_exists?(:expenses, :replaces_expense_id, name: "index_expenses_on_replaces_expense_id_unique")
      create_table :expense_description_revisions, id: :uuid, default: -> { "uuidv7()" } do |t|
        t.references :expense, null: false, type: :uuid, foreign_key: true
        t.references :actor_user, null: false, type: :uuid, foreign_key: { to_table: :users }
        t.string :previous_description, null: false
        t.string :new_description, null: false
        t.datetime :created_at, null: false
      end unless table_exists?(:expense_description_revisions)
      add_index :expense_description_revisions, %i[expense_id created_at] unless index_exists?(:expense_description_revisions, %i[expense_id created_at])
      remove_index :expense_description_revisions, :expense_id if index_exists?(:expense_description_revisions, :expense_id)
      execute <<~SQL
        CREATE FUNCTION prevent_expense_share_mutation() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'expense shares are append-only' USING ERRCODE = '55000'; END; $$;
        CREATE TRIGGER expense_shares_append_only BEFORE UPDATE OR DELETE ON expense_shares FOR EACH ROW EXECUTE FUNCTION prevent_expense_share_mutation();
        CREATE FUNCTION prevent_expense_description_revision_mutation() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'expense description revisions are append-only' USING ERRCODE = '55000'; END; $$;
        CREATE TRIGGER expense_description_revisions_append_only BEFORE UPDATE OR DELETE ON expense_description_revisions FOR EACH ROW EXECUTE FUNCTION prevent_expense_description_revision_mutation();
        CREATE FUNCTION prevent_future_expense_description_revision() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.created_at > clock_timestamp() THEN RAISE EXCEPTION 'expense description revision cannot be future-dated' USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;
        CREATE TRIGGER expense_description_revisions_no_future_timestamp BEFORE INSERT ON expense_description_revisions FOR EACH ROW EXECUTE FUNCTION prevent_future_expense_description_revision();
        CREATE FUNCTION validate_expense_replacement() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE original_group_id uuid; original_voided_at timestamp; original_voided_by_user_id uuid;
        BEGIN
          IF NEW.replaces_expense_id IS NULL THEN RETURN NULL; END IF;
          SELECT group_id, voided_at, voided_by_user_id INTO original_group_id, original_voided_at, original_voided_by_user_id FROM expenses WHERE id = NEW.replaces_expense_id;
          IF original_group_id IS NULL OR original_group_id IS DISTINCT FROM NEW.group_id OR original_voided_at IS NULL OR original_voided_by_user_id IS DISTINCT FROM NEW.created_by_user_id THEN RAISE EXCEPTION 'expense replacement must preserve the voiding actor in the same group' USING ERRCODE = '23514'; END IF;
          RETURN NULL;
        END;
        $$;
        CREATE CONSTRAINT TRIGGER expense_replacement_integrity AFTER INSERT OR UPDATE OF replaces_expense_id, group_id ON expenses DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION validate_expense_replacement();
        CREATE FUNCTION require_expense_description_revision() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF NEW.description IS NOT DISTINCT FROM OLD.description THEN RETURN NULL; END IF;
          IF NOT EXISTS (SELECT 1 FROM (SELECT previous_description, new_description FROM expense_description_revisions WHERE expense_id = NEW.id ORDER BY created_at DESC, id DESC LIMIT 1) latest_revision WHERE latest_revision.previous_description = OLD.description AND latest_revision.new_description = NEW.description) THEN RAISE EXCEPTION 'expense description update requires the latest append-only revision' USING ERRCODE = '23514'; END IF;
          RETURN NULL;
        END;
        $$;
        CREATE CONSTRAINT TRIGGER expense_description_revision_guard AFTER UPDATE OF description ON expenses DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION require_expense_description_revision();
        CREATE FUNCTION protect_expense_history() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'expenses are append-only' USING ERRCODE = '55000'; END IF;
          IF NEW.created_at IS DISTINCT FROM OLD.created_at OR NEW.group_id IS DISTINCT FROM OLD.group_id OR NEW.paid_by_user_id IS DISTINCT FROM OLD.paid_by_user_id OR NEW.created_by_user_id IS DISTINCT FROM OLD.created_by_user_id OR NEW.amount_cents IS DISTINCT FROM OLD.amount_cents OR NEW.occurred_on IS DISTINCT FROM OLD.occurred_on OR NEW.replaces_expense_id IS DISTINCT FROM OLD.replaces_expense_id THEN RAISE EXCEPTION 'financial expense history is immutable' USING ERRCODE = '55000'; END IF;
          IF OLD.voided_at IS NULL THEN
            IF NEW.voided_at IS NULL AND NEW.voided_by_user_id IS NULL AND NEW.void_reason IS NULL THEN RETURN NEW; END IF;
            IF NEW.voided_at IS NULL OR NEW.voided_by_user_id IS NULL OR NEW.void_reason IS NULL THEN RAISE EXCEPTION 'expense void metadata must transition atomically' USING ERRCODE = '55000'; END IF;
            RETURN NEW;
          END IF;
          IF NEW.voided_at IS DISTINCT FROM OLD.voided_at OR NEW.voided_by_user_id IS DISTINCT FROM OLD.voided_by_user_id OR NEW.void_reason IS DISTINCT FROM OLD.void_reason THEN RAISE EXCEPTION 'expense void metadata is immutable' USING ERRCODE = '55000'; END IF;
          RETURN NEW;
        END;
        $$;
        CREATE TRIGGER expenses_history_guard BEFORE UPDATE OR DELETE ON expenses FOR EACH ROW EXECUTE FUNCTION protect_expense_history();
      SQL
    end
  end

  def down
    with_lock_timeout do
      execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM financial_command_receipts WHERE command_type = 'expense_correct') OR EXISTS (SELECT 1 FROM expense_description_revisions) THEN RAISE EXCEPTION 'cannot downgrade phase 9 history with corrections or description revisions' USING ERRCODE = '55000'; END IF; END; $$"
      execute "DROP TRIGGER IF EXISTS expense_description_revision_guard ON expenses"
      execute "DROP FUNCTION IF EXISTS require_expense_description_revision()"
      execute "DROP TRIGGER IF EXISTS expense_replacement_integrity ON expenses"
      execute "DROP FUNCTION IF EXISTS validate_expense_replacement()"
      execute "DROP TRIGGER IF EXISTS expense_description_revisions_append_only ON expense_description_revisions"
      execute "DROP FUNCTION IF EXISTS prevent_expense_description_revision_mutation()"
      execute "DROP TRIGGER IF EXISTS expense_description_revisions_no_future_timestamp ON expense_description_revisions"
      execute "DROP FUNCTION IF EXISTS prevent_future_expense_description_revision()"
      drop_table :expense_description_revisions
      execute "DROP TRIGGER IF EXISTS expense_shares_append_only ON expense_shares"
      execute "DROP FUNCTION IF EXISTS prevent_expense_share_mutation()"
      execute "DROP TRIGGER IF EXISTS expenses_history_guard ON expenses"
      execute "DROP FUNCTION IF EXISTS protect_expense_history()"
      remove_index :expenses, name: "index_expenses_on_replaces_expense_id_unique" if index_exists?(:expenses, :replaces_expense_id, name: "index_expenses_on_replaces_expense_id_unique")
      remove_index :financial_command_receipts, name: "index_financial_receipts_on_expense_and_type" if index_exists?(:financial_command_receipts, %i[expense_id command_type], name: "index_financial_receipts_on_expense_and_type")
      remove_index :financial_command_receipts, name: "index_financial_receipts_on_payment_and_type" if index_exists?(:financial_command_receipts, %i[payment_id command_type], name: "index_financial_receipts_on_payment_and_type")
      add_index :financial_command_receipts, :expense_id unless index_exists?(:financial_command_receipts, :expense_id)
      add_index :financial_command_receipts, %i[payment_id command_type], unique: true unless index_exists?(:financial_command_receipts, %i[payment_id command_type], unique: true)
      remove_check_constraint :financial_command_receipts, name: "financial_command_receipts_result_matches_type"
      remove_reference :financial_command_receipts, :expense, foreign_key: true
      change_column_null :financial_command_receipts, :payment_id, false
      add_check_constraint :financial_command_receipts, "command_type IN ('report', 'confirm', 'cancel')", name: "payment_command_receipts_command_type_valid"
      rename_table :financial_command_receipts, :payment_command_receipts
    end
  end

  private

  def with_lock_timeout
    previous = connection.select_value("SHOW lock_timeout")
    execute "SET lock_timeout = '2s'"
    yield
  ensure
    execute "SET lock_timeout = #{connection.quote(previous)}" if previous
  end
end
