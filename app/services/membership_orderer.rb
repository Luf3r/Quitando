class MembershipOrderer < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:, membership_ids:)
    @group_id = group_id
    @actor_user_id = actor_user_id
    @membership_ids = membership_ids
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id)
    raise InvalidInput, "lista de memberships inválida" unless membership_ids.is_a?(Array)
    validate_persisted_ids!(*membership_ids)
    raise InvalidInput, "lista de memberships inválida" unless membership_ids.uniq.length == membership_ids.length

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?
      raise Forbidden, "membership owner ativa obrigatória" unless Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?

      memberships = Membership.where(group:).lock.to_a
      raise InvalidInput, "lista de memberships inválida" unless memberships.map(&:id).sort == membership_ids.sort

      Membership.connection.execute("SET CONSTRAINTS memberships_group_position_unique DEFERRED")
      membership_ids.each_with_index { |membership_id, position| memberships.find { |membership| membership.id == membership_id }.update!(position:) }
      memberships_by_id = memberships.index_by(&:id)
      membership_ids.map { |membership_id| memberships_by_id.fetch(membership_id).reload }
    end
  end

  private

  attr_reader :group_id, :actor_user_id, :membership_ids
end
