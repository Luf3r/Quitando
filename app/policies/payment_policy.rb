class PaymentPolicy < Struct.new(:user, :payment)
  def show?
    active_member?
  end

  def confirm?
    active_member? && payment.to_user_id == user.id
  end

  def cancel?
    active_member? && [ payment.from_user_id, payment.to_user_id ].include?(user.id)
  end

  private

  def active_member?
    user.present? && payment.group.memberships.where(user_id: user.id, status: :active).exists?
  end
end
