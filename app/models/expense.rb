class Expense < ApplicationRecord
  belongs_to :group
  belongs_to :paid_by_user, class_name: "User"
  belongs_to :created_by_user, class_name: "User"
  belongs_to :voided_by_user, class_name: "User", optional: true
  belongs_to :replaces_expense, class_name: "Expense", optional: true
  has_many :replacement_expenses, class_name: "Expense", foreign_key: :replaces_expense_id, dependent: :restrict_with_exception
  has_many :expense_shares, dependent: :restrict_with_exception
end
