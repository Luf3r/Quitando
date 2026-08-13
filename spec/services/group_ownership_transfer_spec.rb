require "rails_helper"

RSpec.describe GroupOwnershipTransfer do
  describe ".call" do
    it "promove o alvo ativo e rebaixa somente o owner ator" do
      group = create(:group)
      actor = create(:user)
      other_owner = create(:user)
      target = create(:user)
      actor_membership = create(:membership, group:, user: actor, role: :owner, position: 0)
      create(:membership, group:, user: other_owner, role: :owner, position: 1)
      target_membership = create(:membership, group:, user: target, role: :member, position: 2)

      result = described_class.call(group_id: group.id, actor_user_id: actor.id, new_owner_user_id: target.id)

      expect(result.previous_owner_membership).to have_attributes(id: actor_membership.id, role: "member", status: "active")
      expect(result.new_owner_membership).to have_attributes(id: target_membership.id, role: "owner", status: "active")
      expect(Membership.find_by(group:, user: other_owner)).to have_attributes(role: "owner", status: "active")
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "recusa alvo inativo e ator sem ownership ativa" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      inactive_target = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      create(:membership, group:, user: member, role: :member, position: 1)
      create(:membership, group:, user: inactive_target, role: :member, status: :inactive, position: 2)

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id, new_owner_user_id: inactive_target.id)
      }.to raise_error(GroupCommand::InvalidTransition, "novo owner deve estar ativo")

      expect {
        described_class.call(group_id: group.id, actor_user_id: member.id, new_owner_user_id: owner.id)
      }.to raise_error(GroupCommand::Forbidden, "membership owner ativa obrigatória")
    end
  end
end
