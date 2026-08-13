require "rails_helper"

RSpec.describe MembershipDeactivator do
  describe ".call" do
    it "permite que membro ativo saia quando não há saldos nem pagamentos pendentes" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: member, role: :member, position: 1)

      deactivated = described_class.call(group_id: group.id, actor_user_id: member.id, user_id: member.id)

      expect(deactivated).to have_attributes(id: membership.id, status: "inactive")
      expect(group.reload.financial_state_version).to eq(0)
    end
  end
end
