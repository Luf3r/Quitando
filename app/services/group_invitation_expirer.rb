class GroupInvitationExpirer < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(invitation_id:)
    @invitation_id = invitation_id
  end

  def call
    validate_persisted_ids!(invitation_id)
    group_id = GroupInvitation.where(id: invitation_id).pick(:group_id) || raise(NotFound, "convite não encontrado")

    Group.transaction do
      Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      invitation = GroupInvitation.lock.find_by(id: invitation_id) || raise(NotFound, "convite não encontrado")
      return invitation if invitation.expired?

      raise InvalidTransition, "convite não está pendente" unless invitation.pending?
      raise InvalidTransition, "convite ainda não venceu" if invitation.expires_at > Time.current

      invitation.update!(status: :expired, expired_at: Time.current)
      invitation
    end
  end

  private

  attr_reader :invitation_id
end
