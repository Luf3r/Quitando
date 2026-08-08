class FinancialCommandReceipt < ApplicationRecord
  belongs_to :payment, optional: true
  belongs_to :expense, optional: true

  enum :command_type, { report: "report", confirm: "confirm", cancel: "cancel", expense_correct: "expense_correct" }

  before_update :prevent_modification
  before_destroy :prevent_modification

  private

  def prevent_modification
    raise ActiveRecord::ReadOnlyRecord, "Financial command receipts are append-only"
  end
end
