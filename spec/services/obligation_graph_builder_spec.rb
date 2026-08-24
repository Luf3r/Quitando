require "rails_helper"

RSpec.describe ObligationGraphBuilder do
  describe ".call" do
    it "produz uma obrigação da share de não pagador para o pagador" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      expense = create(:expense, group:, paid_by_user: payer, created_by_user: payer, amount_cents: 300)
      create(:expense_share, expense:, user: participant, amount_owed_cents: 300, position: 0)

      result = described_class.call(group)
      obligation = described_class::Edge.new(
        from_user_id: participant.id,
        to_user_id: payer.id,
        amount_cents: 300
      )

      expect(result).to eq(
        described_class::Result.new(
          expense_obligations: [ obligation ],
          bilateral_obligations: [ obligation ]
        )
      )
    end

    it "ignora a share do pagador e agrega contribuições do mesmo par e sentido" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      first_expense = create(
        :expense,
        group:,
        paid_by_user: payer,
        created_by_user: payer,
        amount_cents: 500
      )
      create(:expense_share, expense: first_expense, user: payer, amount_owed_cents: 200, position: 0)
      create(:expense_share, expense: first_expense, user: participant, amount_owed_cents: 300, position: 1)
      second_expense = create(
        :expense,
        group:,
        paid_by_user: payer,
        created_by_user: participant,
        amount_cents: 400
      )
      create(:expense_share, expense: second_expense, user: participant, amount_owed_cents: 400, position: 0)

      result = described_class.call(group)
      obligation = described_class::Edge.new(
        from_user_id: participant.id,
        to_user_id: payer.id,
        amount_cents: 700
      )

      expect(result.expense_obligations).to eq([ obligation ])
      expect(result.bilateral_obligations).to eq([ obligation ])
    end

    it "compensa parcialmente sentidos opostos e preserva as relações históricas agregadas" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      expense_paid_by_ana = create(
        :expense,
        group:,
        paid_by_user: ana,
        created_by_user: ana,
        amount_cents: 700
      )
      create(:expense_share, expense: expense_paid_by_ana, user: bruno, amount_owed_cents: 700, position: 0)
      expense_paid_by_bruno = create(
        :expense,
        group:,
        paid_by_user: bruno,
        created_by_user: bruno,
        amount_cents: 250
      )
      create(:expense_share, expense: expense_paid_by_bruno, user: ana, amount_owed_cents: 250, position: 0)

      result = described_class.call(group)
      expense_obligations = [
        described_class::Edge.new(from_user_id: bruno.id, to_user_id: ana.id, amount_cents: 700),
        described_class::Edge.new(from_user_id: ana.id, to_user_id: bruno.id, amount_cents: 250)
      ].sort_by { |edge| [ edge.from_user_id, edge.to_user_id ] }

      expect(result.expense_obligations).to eq(expense_obligations)
      expect(result.bilateral_obligations).to eq(
        [ described_class::Edge.new(from_user_id: bruno.id, to_user_id: ana.id, amount_cents: 450) ]
      )
    end

    it "remove da camada bilateral relações totalmente compensadas" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      create_obligation(group:, payer: ana, participant: bruno, amount_cents: 500)
      create_obligation(group:, payer: bruno, participant: ana, amount_cents: 500)

      result = described_class.call(group)

      expect(result.expense_obligations.size).to eq(2)
      expect(result.bilateral_obligations).to eq([])
    end

    it "ignora despesas anuladas e despesas de outro grupo" do
      group = create(:group)
      other_group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      active_expense = create_obligation(group:, payer: ana, participant: bruno, amount_cents: 300)
      voided_expense = create_obligation(group:, payer: bruno, participant: ana, amount_cents: 200)
      voided_expense.update!(
        voided_by_user: ana,
        voided_at: Time.current,
        void_reason: "Duplicada"
      )
      create_obligation(group: other_group, payer: bruno, participant: ana, amount_cents: 900)

      expect(described_class.call(group).expense_obligations).to eq(
        [
          described_class::Edge.new(
            from_user_id: bruno.id,
            to_user_id: ana.id,
            amount_cents: active_expense.amount_cents
          )
        ]
      )
    end

    it "ordena ambas as camadas por origem e destino" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      create_obligation(group:, payer: carla, participant: bruno, amount_cents: 300)
      create_obligation(group:, payer: ana, participant: carla, amount_cents: 200)
      create_obligation(group:, payer: bruno, participant: ana, amount_cents: 100)

      result = described_class.call(group)

      expect(result.expense_obligations).to eq(
        result.expense_obligations.sort_by { |edge| [ edge.from_user_id, edge.to_user_id ] }
      )
      expect(result.bilateral_obligations).to eq(
        result.bilateral_obligations.sort_by { |edge| [ edge.from_user_id, edge.to_user_id ] }
      )
    end

    it "mantém Integer quando o agregado derivado excede bigint" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      individual_amount = 9_000_000_000_000_000_000
      2.times do
        create_obligation(group:, payer:, participant:, amount_cents: individual_amount)
      end

      obligation = described_class.call(group).expense_obligations.fetch(0)

      expect(obligation.amount_cents).to eq(18_000_000_000_000_000_000)
      expect(obligation.amount_cents).to be_an(Integer)
    end

    it "mantém participante inativo quando ele faz parte do histórico" do
      group = create(:group)
      payer = create(:user)
      inactive_participant = create(:user)
      create(:membership, group:, user: payer, position: 0)
      create(:membership, group:, user: inactive_participant, status: :inactive, position: 1)
      create_obligation(group:, payer:, participant: inactive_participant, amount_cents: 400)

      expect(described_class.call(group).expense_obligations).to contain_exactly(
        described_class::Edge.new(
          from_user_id: inactive_participant.id,
          to_user_id: payer.id,
          amount_cents: 400
        )
      )
    end

    it "não altera fatos financeiros, versão do grupo ou a entrada" do
      group = create(:group, financial_state_version: 7)
      payer = create(:user)
      participant = create(:user)
      expense = create_obligation(group:, payer:, participant:, amount_cents: 300)
      input_attributes = group.attributes.deep_dup
      expense_attributes = expense.reload.attributes.deep_dup
      share_attributes = expense.expense_shares.first.attributes.deep_dup
      writes = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        sql = event.payload[:sql]
        writes << sql if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\b/i)
      end

      described_class.call(group)

      expect(group.attributes).to eq(input_attributes)
      expect(group.reload.financial_state_version).to eq(7)
      expect(expense.reload.attributes).to eq(expense_attributes)
      expect(expense.expense_shares.first.reload.attributes).to eq(share_attributes)
      expect(writes).to eq([])
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  def create_obligation(group:, payer:, participant:, amount_cents:)
    expense = create(
      :expense,
      group:,
      paid_by_user: payer,
      created_by_user: payer,
      amount_cents:
    )
    create(:expense_share, expense:, user: participant, amount_owed_cents: amount_cents, position: 0)
    expense
  end
end
