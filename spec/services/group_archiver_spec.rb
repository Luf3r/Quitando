require "rails_helper"

RSpec.describe GroupArchiver do
  describe ".call" do
    it "arquiva grupo empty por owner ativo sem mudar versão financeira" do
      group = create(:group)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)

      archived = described_class.call(group_id: group.id, actor_user_id: owner.id)

      expect(archived.archived_at).to be_present
      expect(archived.financial_state_version).to eq(0)
    end

    it "recusa grupo open ou convite pendente" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      create(:membership, group:, user: member, position: 1)
      ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.current, amount_text: "2,00", split: { type: :equal, participant_user_ids: [ owner.id, member.id ] })

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id)
      }.to raise_error(GroupCommand::InvalidTransition, "grupo não pode ser arquivado")

      settled_group = create(:group)
      settled_owner = create(:user)
      create(:membership, group: settled_group, user: settled_owner, role: :owner, position: 0)
      create(:group_invitation, group: settled_group, invited_by_user: settled_owner, expires_at: 2.days.from_now)

      expect {
        described_class.call(group_id: settled_group.id, actor_user_id: settled_owner.id)
      }.to raise_error(GroupCommand::InvalidTransition, "grupo possui convite pendente")
    end

    it "arquiva grupo settled e recusa pagamento reported" do
      settled_group = create(:group)
      settled_owner = create(:user)
      settled_member = create(:user)
      create(:membership, group: settled_group, user: settled_owner, role: :owner, position: 0)
      create(:membership, group: settled_group, user: settled_member, position: 1)
      ExpenseCreator.call(group_id: settled_group.id, created_by_user_id: settled_owner.id, paid_by_user_id: settled_owner.id, description: "Jantar", occurred_on: Date.current, amount_text: "2,00", split: { type: :equal, participant_user_ids: [ settled_owner.id, settled_member.id ] })
      create(:payment, :confirmed, group: settled_group, from_user: settled_member, to_user: settled_owner, reported_by_user: settled_member, amount_cents: 100)

      expect(described_class.call(group_id: settled_group.id, actor_user_id: settled_owner.id)).to have_attributes(archived_at: be_present)

      pending_group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group: pending_group, user: owner, role: :owner, position: 0)
      create(:membership, group: pending_group, user: member, position: 1)
      create(:payment, group: pending_group, from_user: member, to_user: owner, reported_by_user: member)

      expect {
        described_class.call(group_id: pending_group.id, actor_user_id: owner.id)
      }.to raise_error(GroupCommand::InvalidTransition, "grupo não pode ser arquivado")
    end
  end
end
