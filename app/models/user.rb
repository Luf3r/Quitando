class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :memberships, dependent: :restrict_with_exception
  has_many :expenses_paid, class_name: "Expense", foreign_key: :paid_by_user_id, dependent: :restrict_with_exception
  has_many :expenses_created, class_name: "Expense", foreign_key: :created_by_user_id, dependent: :restrict_with_exception
  has_many :expenses_voided, class_name: "Expense", foreign_key: :voided_by_user_id, dependent: :restrict_with_exception
  has_many :expense_shares, dependent: :restrict_with_exception
  has_many :payments_sent, class_name: "Payment", foreign_key: :from_user_id, dependent: :restrict_with_exception
  has_many :payments_received, class_name: "Payment", foreign_key: :to_user_id, dependent: :restrict_with_exception
  has_many :payments_reported, class_name: "Payment", foreign_key: :reported_by_user_id, dependent: :restrict_with_exception
  has_many :payments_confirmed, class_name: "Payment", foreign_key: :confirmed_by_user_id, dependent: :restrict_with_exception
  has_many :payments_cancelled, class_name: "Payment", foreign_key: :cancelled_by_user_id, dependent: :restrict_with_exception
end
