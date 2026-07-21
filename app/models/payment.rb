class Payment < ApplicationRecord
  belongs_to :group
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"
  belongs_to :reported_by_user, class_name: "User"
  belongs_to :confirmed_by_user, class_name: "User", optional: true
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  enum :status, { reported: "reported", confirmed: "confirmed", cancelled: "cancelled" }
end
