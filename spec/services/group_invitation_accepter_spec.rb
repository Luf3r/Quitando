require "rails_helper"

RSpec.describe GroupInvitationAccepter do
  describe ".call" do
    it "rejeita IDs inválidos antes de consultar o convite" do
      expect(GroupInvitation).not_to receive(:where)

      expect {
        described_class.call(invitation_id: "não-é-um-uuid", actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b")
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
    end

    it "aceita o próprio convite e cria membership member na próxima posição" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 3)
      invitation = create(:group_invitation, group:, invited_user:, invited_by_user: owner, expires_at: 2.days.from_now)

      result = described_class.call(invitation_id: invitation.id, actor_user_id: invited_user.id)

      expect(result.invitation).to be_accepted
      expect(result.membership).to have_attributes(group_id: group.id, user_id: invited_user.id, role: "member", status: "active", position: 4)
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "aceita convite reativando a membership inativa sem mudar ID, papel ou posição" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: invited_user, role: :owner, status: :inactive, position: 7)
      invitation = create(:group_invitation, group:, invited_user:, invited_by_user: owner, expires_at: 2.days.from_now)

      result = described_class.call(invitation_id: invitation.id, actor_user_id: invited_user.id)

      expect(result.invitation).to be_accepted
      expect(result.membership).to have_attributes(id: membership.id, role: "owner", status: "active", position: 7)
      expect(Membership.where(group:, user: invited_user).count).to eq(1)
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "recusa ator diferente do convidado sem criar membership" do
      invitation = create(:group_invitation, expires_at: 2.days.from_now)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: create(:user).id)
      }.to raise_error(GroupCommand::Forbidden, "somente o convidado pode aceitar")

      expect(invitation.reload).to be_pending
      expect(Membership.where(group: invitation.group, user: invitation.invited_user)).to be_empty
    end

    it "expira convite vencido antes de aceitar e não cria membership" do
      invitation = create(:group_invitation, expires_at: 1.minute.ago)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: invitation.invited_user_id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")

      expect(invitation.reload).to be_expired
      expect(Membership.where(group: invitation.group, user: invitation.invited_user)).to be_empty
    end

    it "recusa repetir aceite terminal" do
      invitation = create(:group_invitation, :accepted)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: invitation.invited_user_id)
      }.to raise_error(GroupCommand::InvalidTransition, "convite não está pendente")
    end

    it "recusa aceite em grupo arquivado sem criar membership" do
      invitation = create(:group_invitation, expires_at: 2.days.from_now)
      invitation.group.update!(archived_at: Time.current)

      expect {
        described_class.call(invitation_id: invitation.id, actor_user_id: invitation.invited_user_id)
      }.to raise_error(GroupCommand::ArchivedGroup, "grupo arquivado")

      expect(Membership.where(group: invitation.group, user: invitation.invited_user)).to be_empty
    end
  end
end
