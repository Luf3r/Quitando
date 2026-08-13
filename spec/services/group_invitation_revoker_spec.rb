require "rails_helper"

RSpec.describe GroupInvitationRevoker do
  describe ".call" do
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
  end
end
