class RemoveRedundantPhaseTwoIndexes < ActiveRecord::Migration[8.1]
  def up
    remove_index :memberships, name: "index_memberships_on_group_id", if_exists: true
    remove_index :expense_shares, name: "index_expense_shares_on_expense_id", if_exists: true
    remove_index :payments, name: "index_payments_on_group_id", if_exists: true
  end

  def down
    add_index :memberships, :group_id unless index_exists?(:memberships, :group_id)
    add_index :expense_shares, :expense_id unless index_exists?(:expense_shares, :expense_id)
    add_index :payments, :group_id unless index_exists?(:payments, :group_id)
  end
end
