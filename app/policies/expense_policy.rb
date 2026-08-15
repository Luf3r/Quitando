class ExpensePolicy < Struct.new(:user, :expense)
  def show?
    active_member?
  end

  def update_description?
    permitted_actor?
  end

  alias_method :correct?, :update_description?

  private

  def active_member?
    user.present? && expense.group.memberships.where(user_id: user.id, status: :active).exists?
  end

  def permitted_actor?
    active_member? && (expense.created_by_user_id == user.id || expense.paid_by_user_id == user.id || expense.group.memberships.where(user_id: user.id, role: :owner, status: :active).exists?)
  end
end
