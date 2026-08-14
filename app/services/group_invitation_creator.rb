class GroupInvitationCreator < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:, invited_user_id:)
    @group_id = group_id
    @actor_user_id = actor_user_id
    @invited_user_id = invited_user_id
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id, invited_user_id)

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?
      raise Forbidden, "membership owner ativa obrigatória" unless owner_active?(group)

      expire_pending_invitations!(group)
      invited_user = User.find_by(id: invited_user_id) || raise(NotFound, "usuário não encontrado")
      raise InvalidTransition, "usuário já possui membership ativa" if Membership.where(group:, user: invited_user, status: :active).exists?
      raise InvalidTransition, "convite pendente já existe" if GroupInvitation.where(group:, invited_user:, status: :pending).exists?

      GroupInvitation.create!(group:, invited_user:, invited_by_user: User.find_by(id: actor_user_id), status: :pending, expires_at: Time.current + 7.days)
    end
  rescue ActiveRecord::RecordNotUnique
    raise InvalidTransition, "convite pendente já existe"
  end

  private

  attr_reader :group_id, :actor_user_id, :invited_user_id

  def owner_active?(group)
    Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?
  end

  def expire_pending_invitations!(group)
    GroupInvitation.where(group:, status: :pending).where(expires_at: ..Time.current).lock.find_each do |invitation|
      invitation.update!(status: :expired, expired_at: Time.current)
    end
  end
end
