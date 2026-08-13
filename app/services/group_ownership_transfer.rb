class GroupOwnershipTransfer < GroupCommand
  Result = Data.define(:previous_owner_membership, :new_owner_membership)

  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:, new_owner_user_id:)
    @group_id = group_id
    @actor_user_id = actor_user_id
    @new_owner_user_id = new_owner_user_id
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id, new_owner_user_id)
    raise InvalidTransition, "novo owner deve ser diferente" if actor_user_id == new_owner_user_id

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?

      memberships = Membership.where(group:, user_id: [ actor_user_id, new_owner_user_id ]).lock.index_by(&:user_id)
      previous_owner = memberships.fetch(actor_user_id) { raise NotFound, "membership não encontrada" }
      new_owner = memberships.fetch(new_owner_user_id) { raise NotFound, "membership não encontrada" }
      raise Forbidden, "membership owner ativa obrigatória" unless previous_owner.owner? && previous_owner.active?
      raise InvalidTransition, "novo owner deve estar ativo" unless new_owner.active?

      previous_owner.update!(role: :member)
      new_owner.update!(role: :owner)
      Result.new(previous_owner, new_owner)
    end
  end

  private

  attr_reader :group_id, :actor_user_id, :new_owner_user_id
end
