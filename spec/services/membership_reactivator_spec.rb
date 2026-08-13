require "rails_helper"

RSpec.describe MembershipReactivator do
  describe ".call" do
    it "rejeita IDs inválidos antes de consultar o grupo" do
      expect(Group).not_to receive(:lock)

      expect {
        described_class.call(
          group_id: "não-é-um-uuid",
          actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
          user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c"
        )
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
    end

    it "permite que owner ativo reative membership preservando ID, papel e posição" do
      group = create(:group)
      owner = create(:user)
      returning_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: returning_user, role: :owner, status: :inactive, position: 4)

      reactivated = described_class.call(group_id: group.id, actor_user_id: owner.id, user_id: returning_user.id)

      expect(reactivated).to have_attributes(id: membership.id, role: "owner", status: "active", position: 4)
      expect(Membership.where(group:, user: returning_user).count).to eq(1)
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "recusa membro comum e membership já ativa" do
      group = create(:group)
      member = create(:user)
      target = create(:user)
      create(:membership, group:, user: member, role: :member, position: 0)
      create(:membership, group:, user: target, role: :member, position: 1)

      expect {
        described_class.call(group_id: group.id, actor_user_id: member.id, user_id: target.id)
      }.to raise_error(GroupCommand::Forbidden, "membership owner ativa obrigatória")

      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 2)

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id, user_id: target.id)
      }.to raise_error(GroupCommand::InvalidTransition, "membership já está ativa")
    end

    it "recusa reativação em grupo arquivado" do
      group = create(:group, archived_at: Time.current)
      owner = create(:user)
      returning_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: returning_user, status: :inactive, position: 1)

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id, user_id: returning_user.id)
      }.to raise_error(GroupCommand::ArchivedGroup, "grupo arquivado")

      expect(membership.reload).to be_inactive
    end
  end
end
