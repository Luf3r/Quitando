class MembershipDeactivator < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:, user_id:)
    @group_id = group_id
    @actor_user_id = actor_user_id
    @user_id = user_id
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id, user_id)

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?

      membership = Membership.lock.find_by(group:, user_id:) || raise(NotFound, "membership não encontrada")
      raise InvalidTransition, "membership já está inativa" unless membership.active?
      raise Forbidden, "owner ativo obrigatório para inativar outro membro" unless actor_authorized?(group)
      official_balances = GroupBalanceCalculator.call(group)
      raise InvalidTransition, "saldo oficial diferente de zero" unless official_balances.fetch(user_id).zero?

      projected_balances = ProjectedBalanceCalculator.call(
        official_balances,
        group.payments.reported.select(:from_user_id, :to_user_id, :amount_cents)
      )
      raise InvalidTransition, "saldo projetado diferente de zero" unless projected_balances.fetch(user_id).zero?
      raise InvalidTransition, "pagamento pendente envolve membership" if reported_payment?(group)
      raise InvalidTransition, "último owner ativo não pode sair" if last_active_owner?(group, membership)

      membership.update!(status: :inactive)
      membership
    end
  end

  private

  attr_reader :group_id, :actor_user_id, :user_id

  def actor_authorized?(group)
    actor_user_id == user_id || Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?
  end

  def reported_payment?(group)
    group.payments.reported.where(from_user_id: user_id).or(group.payments.reported.where(to_user_id: user_id)).exists?
  end

  def last_active_owner?(group, membership)
    membership.owner? && Membership.where(group:, role: :owner, status: :active).count == 1
  end
end
