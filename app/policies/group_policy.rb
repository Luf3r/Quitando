class GroupPolicy < Struct.new(:user, :group)
  def index?
    user.present?
  end

  def create?
    user.present?
  end

  def show?
    user.present? && group.memberships.where(user_id: user.id, status: :active).exists?
  end

  def update?
    user.present? && group.memberships.where(user_id: user.id, role: :owner, status: :active).exists?
  end

  class Scope < Struct.new(:user, :scope)
    def resolve
      scope.joins(:memberships)
           .where(memberships: { user_id: user.id, status: :active })
           .distinct
    end
  end
end
