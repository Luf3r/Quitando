class GroupInvitationDecliner < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(invitation_id:, actor_user_id:)
    @invitation_id = invitation_id
    @actor_user_id = actor_user_id
  end

  def call
    validate_persisted_ids!(invitation_id, actor_user_id)
    group_id = GroupInvitation.where(id: invitation_id).pick(:group_id) || raise(NotFound, "convite não encontrado")

    result = Group.transaction do
      Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      invitation = GroupInvitation.lock.find_by(id: invitation_id) || raise(NotFound, "convite não encontrado")
      next :expired if expire_if_needed!(invitation)

      raise InvalidTransition, "convite não está pendente" unless invitation.pending?
      raise Forbidden, "somente o convidado pode recusar" unless invitation.invited_user_id == actor_user_id

      invitation.update!(status: :declined, declined_at: Time.current)
      invitation
    end

    raise InvalidTransition, "convite não está pendente" if result == :expired

    result
  end

  private

  attr_reader :invitation_id, :actor_user_id

  def expire_if_needed!(invitation)
    return false unless invitation.pending? && invitation.expires_at <= Time.current

    invitation.update!(status: :expired, expired_at: Time.current)
    true
  end
end
