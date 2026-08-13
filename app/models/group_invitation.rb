class GroupInvitation < ApplicationRecord
  belongs_to :group
  belongs_to :invited_user, class_name: "User"
  belongs_to :invited_by_user, class_name: "User"

  enum :status, {
    pending: "pending",
    accepted: "accepted",
    declined: "declined",
    revoked: "revoked",
    expired: "expired"
  }
end
