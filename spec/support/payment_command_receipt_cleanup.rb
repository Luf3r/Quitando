module PaymentCommandReceiptCleanup
  def delete_expense_description_revisions_for_cleanup!(scope)
    connection = ExpenseDescriptionRevision.connection
    trigger_disabled = false
    connection.execute("ALTER TABLE expense_description_revisions DISABLE TRIGGER expense_description_revisions_append_only")
    trigger_disabled = true
    scope.delete_all
  ensure
    connection.execute("ALTER TABLE expense_description_revisions ENABLE TRIGGER expense_description_revisions_append_only") if trigger_disabled
  end

  def delete_payment_command_receipts_for_cleanup!(scope)
    connection = FinancialCommandReceipt.connection
    trigger_disabled = false
    connection.execute("ALTER TABLE #{FinancialCommandReceipt.table_name} DISABLE TRIGGER payment_command_receipts_append_only")
    trigger_disabled = true
    scope.delete_all
  ensure
    connection.execute("ALTER TABLE #{FinancialCommandReceipt.table_name} ENABLE TRIGGER payment_command_receipts_append_only") if trigger_disabled
  end

  def delete_expense_history_for_cleanup!(expense_scope)
    connection = Expense.connection
    connection.execute("ALTER TABLE expense_shares DISABLE TRIGGER expense_shares_append_only")
    connection.execute("ALTER TABLE expenses DISABLE TRIGGER expenses_history_guard")
    ExpenseShare.where(expense_id: expense_scope.select(:id)).delete_all
    expense_scope.delete_all
  ensure
    connection.execute("ALTER TABLE expenses ENABLE TRIGGER expenses_history_guard") if connection
    connection.execute("ALTER TABLE expense_shares ENABLE TRIGGER expense_shares_append_only") if connection
  end
end
