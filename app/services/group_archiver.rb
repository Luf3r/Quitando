class GroupArchiver < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:)
    @group_id = group_id
    @actor_user_id = actor_user_id
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id)

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?
      raise Forbidden, "membership owner ativa obrigatória" unless Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?

      expire_pending_invitations!(group)
      raise InvalidTransition, "grupo não pode ser arquivado" unless %i[empty settled].include?(GroupFinancialStatusResolver.call(group))
      raise InvalidTransition, "grupo possui convite pendente" if group.group_invitations.pending.exists?

      group.update!(archived_at: Time.current)
      group
    end
  end

  private

  attr_reader :group_id, :actor_user_id

  def expire_pending_invitations!(group)
    group.group_invitations.pending.where(expires_at: ..Time.current).lock.find_each do |invitation|
      invitation.update!(status: :expired, expired_at: Time.current)
    end
  end
end
