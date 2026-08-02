require "rails_helper"
require "pbt"

RSpec.describe SettlementPlanGenerator, "property tests" do
  def amount_text(amount_cents)
    format("%d,%02d", amount_cents / 100, amount_cents % 100)
  end

  def verify_plan!(balances, transfers)
    raise "a soma do ledger não é zero" unless balances.values.sum.zero?
    raise "o plano recebeu participante sem String" unless balances.keys.all?(String)
    raise "o plano recebeu saldo sem Integer" unless balances.values.all?(Integer)
    raise "o plano referencia participante externo" unless transfers.all? { |transfer| balances.key?(transfer.from_user_id) && balances.key?(transfer.to_user_id) }

    remaining = balances.dup
    transfers.each do |transfer|
      remaining[transfer.from_user_id] += transfer.amount_cents
      remaining[transfer.to_user_id] -= transfer.amount_cents
    end
    raise "o plano não quita os saldos" unless remaining.values.all?(&:zero?)
  end

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

  it "quita a projeção sem persistir ou mutar fatos em 30 históricos com reports parciais e totais" do
    seed = Integer(ENV.fetch("PBT_SEED", "280802"))
    RSpec.configuration.reporter.message(
      "PBT seed: #{seed}; execuções: 30 por modo parcial/total; worker: none; shrinking: habilitado"
    )

    Pbt.assert(num_runs: 30, worker: :none, seed:) do
      Pbt.property(Pbt.integer(min: 4, max: 10_000)) do |amount_cents|
        [ :partial, :total ].each do |report_mode|
          group = create(:group)
          payer = create(:user)
          participant = create(:user)
          [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
          ExpenseCreator.call(
            group_id: group.id,
            created_by_user_id: payer.id,
            paid_by_user_id: payer.id,
            description: "Histórico",
            occurred_on: Date.new(2026, 8, 2),
            amount_text: amount_text(amount_cents),
            split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
          )

          official_balances = GroupBalanceCalculator.call(group)
          original_official_balances = official_balances.dup
          original_transfer = described_class.call(group).fetch(0)
          report_amount_cents = report_mode == :partial ? original_transfer.amount_cents - 1 : original_transfer.amount_cents
          create(
            :payment,
            group:,
            from_user: participant,
            to_user: payer,
            amount_cents: report_amount_cents,
            reported_by_user: participant
          )
          snapshot_before_reads = financial_snapshot(group)
          projected_balances = ProjectedBalanceCalculator.call(official_balances, group.payments.reported)
          transfers = described_class.call(group)

          verify_plan!(projected_balances, transfers)
          raise "o saldo oficial foi modificado" unless official_balances == original_official_balances
          raise "o plano não é determinístico" unless described_class.call(group) == transfers
          raise "a leitura persistiu ou alterou fatos" unless financial_snapshot(group) == snapshot_before_reads
        end
      end
    end
  end

  it "detecta um plano vazio para saldos não zerados" do
    balances = {
      "018f0f3e-7b6c-7a10-8b2c-1234567890ab" => -300,
      "018f0f3e-7b6c-7a11-9b2c-1234567890ab" => 300
    }

    expect { verify_plan!(balances, []) }.to raise_error("o plano não quita os saldos")
  end
end
