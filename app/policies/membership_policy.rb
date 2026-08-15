class MembershipPolicy < Struct.new(:user, :membership)
  def deactivate?
    active_member? && (membership.user_id == user.id || owner?)
  end

  def reactivate?
    active_member? && owner?
  end

  def transfer_ownership?
    active_member? && owner?
  end

  private

  def active_member?
    user.present? && membership.group.memberships.where(user_id: user.id, status: :active).exists?
  end

  def owner?
    membership.group.memberships.where(user_id: user.id, role: :owner, status: :active).exists?
  end
end
