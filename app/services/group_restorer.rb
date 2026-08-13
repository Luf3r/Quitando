class GroupRestorer < GroupCommand
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
      raise InvalidTransition, "grupo não está arquivado" unless group.archived_at?
      raise Forbidden, "membership owner ativa obrigatória" unless Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?

      group.update!(archived_at: nil)
      group
    end
  end

  private

  attr_reader :group_id, :actor_user_id
end
