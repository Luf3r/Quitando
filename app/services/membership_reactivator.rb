class MembershipReactivator < GroupCommand
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
      raise Forbidden, "membership owner ativa obrigatória" unless owner_active?(group)

      membership = Membership.lock.find_by(group:, user_id:) || raise(NotFound, "membership não encontrada")
      raise InvalidTransition, "membership já está ativa" if membership.active?

      membership.update!(status: :active)
      membership
    end
  end

  private

  attr_reader :group_id, :actor_user_id, :user_id

  def owner_active?(group)
    Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?
  end
end
