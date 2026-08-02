module PaymentCommandReceiptCleanup
  def delete_payment_command_receipts_for_cleanup!(scope)
    connection = PaymentCommandReceipt.connection
    trigger_disabled = false
    connection.execute("ALTER TABLE payment_command_receipts DISABLE TRIGGER payment_command_receipts_append_only")
    trigger_disabled = true
    scope.delete_all
  ensure
    connection.execute("ALTER TABLE payment_command_receipts ENABLE TRIGGER payment_command_receipts_append_only") if trigger_disabled
  end
end
