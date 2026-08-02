class PaymentCommandReceipt < ApplicationRecord
  belongs_to :payment

  enum :command_type, { report: "report", confirm: "confirm", cancel: "cancel" }

  before_update :prevent_modification
  before_destroy :prevent_modification

  private

  def prevent_modification
    raise ActiveRecord::ReadOnlyRecord, "Payment command receipts are append-only"
  end
end
