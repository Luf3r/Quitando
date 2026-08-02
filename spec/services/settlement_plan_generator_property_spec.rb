require "rails_helper"
require "pbt"

RSpec.describe SettlementPlanGenerator, "property tests" do
  def amount_text(amount_cents)
    format("%d,%02d", amount_cents / 100, amount_cents % 100)
  end

  def verify_plan!(balances, transfers)
    raise "a soma do ledger não é zero" unless balances.values.sum.zero?
    raise "o plano referencia participante externo" unless transfers.all? { |transfer| balances.key?(transfer.from_user_id) && balances.key?(transfer.to_user_id) }

    remaining = balances.dup
    transfers.each do |transfer|
      remaining[transfer.from_user_id] += transfer.amount_cents
      remaining[transfer.to_user_id] -= transfer.amount_cents
    end
    raise "o plano não quita os saldos" unless remaining.values.all?(&:zero?)
  end

  it "preserva quitação, determinismo, escopo e imutabilidade em 30 históricos persistidos" do
    seed = Integer(ENV.fetch("PBT_SEED", "280802"))
    RSpec.configuration.reporter.message("PBT seed: #{seed}; execuções: 30; worker: none; shrinking: habilitado")

    Pbt.assert(num_runs: 30, worker: :none, seed:) do
      Pbt.property(Pbt.integer(min: 2, max: 10_000)) do |amount_cents|
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

        balances = GroupBalanceCalculator.call(group)
        original_balances = balances.dup
        transfers = described_class.call(group)

        verify_plan!(balances, transfers)
        raise "o saldo oficial foi modificado" unless balances == original_balances
        raise "o plano não é determinístico" unless described_class.call(group) == transfers
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
