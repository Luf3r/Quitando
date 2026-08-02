class Payment < ApplicationRecord
  belongs_to :group
  has_many :command_receipts, class_name: "PaymentCommandReceipt", dependent: :restrict_with_exception
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"
  belongs_to :reported_by_user, class_name: "User"
  belongs_to :confirmed_by_user, class_name: "User", optional: true
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  enum :status, { reported: "reported", confirmed: "confirmed", cancelled: "cancelled" }
end
