class Group < ApplicationRecord
  has_many :memberships, dependent: :restrict_with_exception
  has_many :group_invitations, dependent: :restrict_with_exception
  has_many :expenses, dependent: :restrict_with_exception
  has_many :payments, dependent: :restrict_with_exception
  has_many :payment_command_receipts, through: :payments, source: :command_receipts
end
