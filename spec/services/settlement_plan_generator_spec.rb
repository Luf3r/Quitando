require "rails_helper"

RSpec.describe SettlementPlanGenerator do
  def financial_snapshot(group)
    {
      group: group.reload.attributes.slice("financial_state_version"),
      expenses: group.expenses.order(:id).pluck(*Expense.column_names),
      shares: ExpenseShare.joins(:expense)
        .where(expenses: { group_id: group.id })
        .order(:id)
        .pluck(*ExpenseShare.column_names.map { |column| "expense_shares.#{column}" }),
      payments: group.payments.order(:id).pluck(*Payment.column_names)
    }
  end

  describe ".call" do
    it "retorna um plano vazio para um grupo sem movimentação" do
      group = create(:group)

      expect(described_class.call(group)).to eq([])
    end

    it "gera a transferência que quita uma despesa simples" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      create(:membership, group:, user: payer, position: 0)
      create(:membership, group:, user: participant, position: 1)
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: payer.id,
        paid_by_user_id: payer.id,
        description: "Jantar",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "6,00",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
      )

      expect(described_class.call(group)).to eq(
        [ DebtSimplifier::Transfer.new(from_user_id: participant.id, to_user_id: payer.id, amount_cents: 300) ]
      )
    end

    it "é determinístico, usa somente participantes do grupo e quita o saldo oficial" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      outsider = create(:user)
      [ ana, bruno, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      other_group = create(:group)
      create(:membership, group: other_group, user: outsider, position: 0)
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: ana.id,
        paid_by_user_id: ana.id,
        description: "Mercado",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "9,00",
        split: { type: :equal, participant_user_ids: [ ana.id, bruno.id, carla.id ] }
      )

      balances = GroupBalanceCalculator.call(group)
      transfers = described_class.call(group)
      remaining_balances = balances.dup
      transfers.each do |transfer|
        remaining_balances[transfer.from_user_id] += transfer.amount_cents
        remaining_balances[transfer.to_user_id] -= transfer.amount_cents
      end

      expect(described_class.call(group)).to eq(transfers)
      expect(transfers.flat_map { |transfer| [ transfer.from_user_id, transfer.to_user_id ] }).to all(be_in(balances.keys))
      expect(remaining_balances.values).to all(eq(0))
    end

    it "propaga a inconsistência do ledger" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense = create(:expense, group:, paid_by_user: payer, created_by_user: payer, amount_cents: 100)
      create(:expense_share, expense:, user: participant, amount_owed_cents: 99, position: 0)

      expect { described_class.call(group) }.to raise_error(GroupBalanceCalculator::UnbalancedLedger)
    end

    it "não altera fatos financeiros persistidos" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: payer.id,
        paid_by_user_id: payer.id,
        description: "Jantar",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "6,00",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
      )
      snapshot = financial_snapshot(group)

      described_class.call(group)

      expect(financial_snapshot(group)).to eq(snapshot)
    end

    it "detecta uma escrita financeira no controle negativo restrito à spec" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense = ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: payer.id,
        paid_by_user_id: payer.id,
        description: "Jantar",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "6,00",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
      )
      snapshot = financial_snapshot(group)

      Expense.where(id: expense.id).update_all(description: "Jantar corrigido")

      expect(financial_snapshot(group)).not_to eq(snapshot)
    end

    it "sugere Carla para Ana quando a obrigação histórica de Carla surgiu com Diego" do
      group = create(:group)
      ana = create(:user)
      diego = create(:user)
      carla = create(:user)
      [ ana, diego, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: ana.id,
        paid_by_user_id: ana.id,
        description: "Hospedagem",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "6,00",
        split: { type: :exact, shares: [ { user_id: ana.id, amount_text: "3,00" }, { user_id: diego.id, amount_text: "3,00" } ] }
      )
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: diego.id,
        paid_by_user_id: diego.id,
        description: "Mercado",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "3,00",
        split: { type: :exact, shares: [ { user_id: carla.id, amount_text: "3,00" } ] }
      )

      transfers = described_class.call(group)

      expect(GroupBalanceCalculator.call(group)).to eq(ana.id => 300, diego.id => 0, carla.id => -300)
      expect(transfers).to eq([ DebtSimplifier::Transfer.new(from_user_id: carla.id, to_user_id: ana.id, amount_cents: 300) ])
      expect(SettlementPlanTextPresenter.call(transfers)).to eq([ "#{carla.id} paga 300 centavos para #{ana.id}" ])
    end
  end
end
