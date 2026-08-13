require "rails_helper"

RSpec.describe GroupInvitationDecliner do
  describe ".call" do
    it "rejeita IDs inválidos antes de consultar o convite" do
      expect(GroupInvitation).not_to receive(:where)

      expect {
        described_class.call(invitation_id: "não-é-um-uuid", actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b")
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
    end

    it "permite que o próprio convidado recuse uma pendência" do
      invited_user = create(:user)
      invitation = create(:group_invitation, invited_user:, expires_at: 2.days.from_now)

      declined = described_class.call(invitation_id: invitation.id, actor_user_id: invited_user.id)

      expect(declined).to be_declined
      expect(declined.declined_at).to be_present
    end

    it "recusa ator diferente do convidado" do
      invitation = create(:group_invitation, expires_at: 2.days.from_now)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: create(:user).id)
      }.to raise_error(GroupCommand::Forbidden, "somente o convidado pode recusar")

      expect(invitation.reload).to be_pending
    end

    it "expira pendência vencida antes de recusar e expõe a transição terminal" do
      invitation = create(:group_invitation, expires_at: 1.minute.ago)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: invitation.invited_user_id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")

      expect(invitation.reload).to be_expired
    end

    it "recusa repetir uma recusa terminal" do
      invitation = create(:group_invitation, :declined)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: invitation.invited_user_id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")
    end
  end
end
