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

    it "bloqueia saída com saldo oficial diferente de zero" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: member, role: :member, position: 1)
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: owner.id,
        paid_by_user_id: owner.id,
        description: "Jantar",
        occurred_on: Date.current,
        amount_text: "2,00",
        split: { type: :equal, participant_user_ids: [ owner.id, member.id ] }
      )

      expect {
        described_class.call(group_id: group.id, actor_user_id: member.id, user_id: member.id)
      }.to raise_error(GroupCommand::InvalidTransition, "saldo oficial diferente de zero")

      expect(membership.reload).to be_active
    end

    it "bloqueia saída com saldo projetado diferente de zero" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: member, role: :member, position: 1)
      create(:payment, group:, from_user: member, to_user: owner, reported_by_user: member, amount_cents: 100)

      expect {
        described_class.call(group_id: group.id, actor_user_id: member.id, user_id: member.id)
      }.to raise_error(GroupCommand::InvalidTransition, "saldo projetado diferente de zero")

      expect(membership.reload).to be_active
    end

    it "bloqueia pagamento reported mesmo quando a projeção líquida é zero" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: member, role: :member, position: 1)
      create(:payment, group:, from_user: member, to_user: owner, reported_by_user: member, amount_cents: 100)
      create(:payment, group:, from_user: owner, to_user: member, reported_by_user: owner, amount_cents: 100)

      expect {
        described_class.call(group_id: group.id, actor_user_id: member.id, user_id: member.id)
      }.to raise_error(GroupCommand::InvalidTransition, "pagamento pendente envolve membership")

      expect(membership.reload).to be_active
    end

    it "permite que owner ativo inative outro membro" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: member, role: :member, position: 1)

      deactivated = described_class.call(group_id: group.id, actor_user_id: owner.id, user_id: member.id)

      expect(deactivated).to have_attributes(id: membership.id, status: "inactive")
    end

    it "recusa ator que não é o alvo nem owner ativo" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      outsider = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      membership = create(:membership, group:, user: member, role: :member, position: 1)

      expect {
        described_class.call(group_id: group.id, actor_user_id: outsider.id, user_id: member.id)
      }.to raise_error(GroupCommand::Forbidden, "owner ativo obrigatório para inativar outro membro")

      expect(membership.reload).to be_active
    end

    it "bloqueia a saída do último owner ativo" do
      group = create(:group)
      owner = create(:user)
      membership = create(:membership, group:, user: owner, role: :owner, position: 0)

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id, user_id: owner.id)
      }.to raise_error(GroupCommand::InvalidTransition, "último owner ativo não pode sair")

      expect(membership.reload).to be_active
    end
  end
end
