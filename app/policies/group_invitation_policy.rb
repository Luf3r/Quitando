class GroupInvitationPolicy < Struct.new(:user, :invitation)
  def index?
    user.present?
  end

  def accept?
    user.present? && invitation.invited_user_id == user.id
  end

  alias_method :decline?, :accept?

  class Scope < Struct.new(:user, :scope)
    def resolve
      scope.where(invited_user_id: user.id, status: :pending)
    end
  end
end
