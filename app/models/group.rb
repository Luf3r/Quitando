class Group < ApplicationRecord
  has_many :memberships, dependent: :restrict_with_exception
  has_many :expenses, dependent: :restrict_with_exception
  has_many :payments, dependent: :restrict_with_exception
end
