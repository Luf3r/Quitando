require "rails_helper"

RSpec.describe GroupInvitationExpirer do
  describe ".call" do
    it "rejeita invitation_id inválido antes de consultar o convite" do
      expect(GroupInvitation).not_to receive(:where)

      expect {
        described_class.call(invitation_id: "não-é-um-uuid")
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
    end

    it "expira uma pendência vencida e repete sem novo efeito" do
      invitation = create(:group_invitation, expires_at: 1.minute.ago)

      expired = described_class.call(invitation_id: invitation.id)
      repeated = described_class.call(invitation_id: invitation.id)

      expect(expired).to be_expired
      expect(repeated).to have_attributes(id: invitation.id, status: "expired", expired_at: expired.expired_at)
    end

    it "recusa expirar convite que ainda não venceu" do
      invitation = create(:group_invitation, expires_at: 2.days.from_now)

      expect {
        described_class.call(invitation_id: invitation.id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite ainda não venceu")

      expect(invitation.reload).to be_pending
    end

    it "recusa repetir uma transição terminal diferente de expiração" do
      invitation = create(:group_invitation, :declined)

      expect {
        described_class.call(invitation_id: invitation.id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")
    end
  end
end
