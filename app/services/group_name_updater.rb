class GroupNameUpdater < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:, name:)
    @group_id = group_id
    @actor_user_id = actor_user_id
    @name = name
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id)
    normalized_name = normalize_name!(name)

    Group.transaction do
      group = Group.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?
      raise Forbidden, "membership owner ativa obrigatória" unless owner_active?(group)

      group.update!(name: normalized_name)
      group
    end
  end

  private

  attr_reader :group_id, :actor_user_id, :name

  def owner_active?(group)
    Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?
  end
end
