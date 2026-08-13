require "rails_helper"

RSpec.describe GroupInvitationRevoker do
  describe ".call" do
    it "rejeita IDs inválidos antes de consultar o convite" do
      expect(GroupInvitation).not_to receive(:where)

      expect {
        described_class.call(invitation_id: "não-é-um-uuid", actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b")
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
    end

    it "permite que owner ativo revogue uma pendência" do
      group = create(:group)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      invitation = create(:group_invitation, group:, invited_by_user: owner, expires_at: 2.days.from_now)

      revoked = described_class.call(invitation_id: invitation.id, actor_user_id: owner.id)

      expect(revoked).to be_revoked
      expect(revoked.revoked_at).to be_present
    end

    it "recusa revogação por membro que não é owner" do
      group = create(:group)
      member = create(:user)
      create(:membership, group:, user: member, role: :member, position: 0)
      invitation = create(:group_invitation, group:, expires_at: 2.days.from_now)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: member.id)
      }.to raise_error(GroupCommand::Forbidden, "membership owner ativa obrigatória")

      expect(invitation.reload).to be_pending
    end

    it "expira pendência vencida antes de revogar e expõe a transição terminal" do
      group = create(:group)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      invitation = create(:group_invitation, group:, invited_by_user: owner, expires_at: 1.minute.ago)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: owner.id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")

      expect(invitation.reload).to be_expired
    end

    it "recusa repetir uma revogação terminal" do
      group = create(:group)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      invitation = create(:group_invitation, :revoked, group:, invited_by_user: owner)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: owner.id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")
    end
  end
end
