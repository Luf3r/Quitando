class Membership < ApplicationRecord
  belongs_to :group
  belongs_to :user
  enum :role, { owner: "owner", member: "member" }
  enum :status, { active: "active", inactive: "inactive" }
end
