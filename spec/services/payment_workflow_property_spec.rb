require "rails_helper"
require "pbt"

RSpec.describe "Payment workflow property tests" do
  def amount_text(cents)
    format("%d,%02d", cents / 100, cents % 100)
  end

  def expected_official_balances_after_confirmation(official_balances, payment)
    official_balances.dup.tap do |balances|
      balances[payment.from_user_id] += payment.amount_cents
      balances[payment.to_user_id] -= payment.amount_cents
    end
  end

  def assert_exact_confirmation_delta!(official_before:, official_after:, payment:)
    expected = expected_official_balances_after_confirmation(official_before, payment)

    raise "a confirmação não aplicou os deltas exatos no ledger oficial" unless official_after == expected
  end

  def balances_without_confirmation_delta(official_balances, _payment)
    official_balances.dup
  end

  it "preserves the projected plan through confirmation and restores it through cancellation" do
    seed = Integer(ENV.fetch("PBT_SEED", "280807"))
    RSpec.configuration.reporter.message(
      "PBT seed: #{seed}; execuções: 20; worker: none; shrinking: habilitado"
    )

    Pbt.assert(num_runs: 20, worker: :none, seed:) do
      Pbt.property(Pbt.integer(min: 4, max: 10_000)) do |amount_cents|
        group = create(:group)
        receiver = create(:user)
        sender = create(:user)
        [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
        ExpenseCreator.call(
          group_id: group.id,
          created_by_user_id: receiver.id,
          paid_by_user_id: receiver.id,
          description: "Histórico",
          occurred_on: Date.new(2026, 8, 2),
          amount_text: amount_text(amount_cents),
          split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }
        )

        official_before_confirmation = GroupBalanceCalculator.call(group.reload)
        transfer = SettlementPlanGenerator.call(group).fetch(0)
        report_cents = [ transfer.amount_cents - 1, 1 ].max
        payment = PaymentReporter.call(
          group_id: group.id,
          actor_user_id: sender.id,
          from_user_id: sender.id,
          to_user_id: receiver.id,
          amount_text: amount_text(report_cents),
          expected_financial_state_version: group.reload.financial_state_version,
          idempotency_key: SecureRandom.uuid
        )
        projected_plan_after_report = SettlementPlanGenerator.call(group.reload)

        PaymentConfirmer.call(
          group_id: group.id,
          payment_id: payment.id,
          actor_user_id: receiver.id,
          idempotency_key: SecureRandom.uuid
        )

        official_after_confirmation = GroupBalanceCalculator.call(group.reload)
        assert_exact_confirmation_delta!(
          official_before: official_before_confirmation,
          official_after: official_after_confirmation,
          payment:
        )
        raise "a confirmação alterou o plano projetado" unless SettlementPlanGenerator.call(group) == projected_plan_after_report

        plan_before_cancellation_report = SettlementPlanGenerator.call(group)
        cancellation_transfer = plan_before_cancellation_report.fetch(0)
        cancellation_report = PaymentReporter.call(
          group_id: group.id,
          actor_user_id: sender.id,
          from_user_id: sender.id,
          to_user_id: receiver.id,
          amount_text: amount_text(cancellation_transfer.amount_cents),
          expected_financial_state_version: group.reload.financial_state_version,
          idempotency_key: SecureRandom.uuid
        )

        PaymentCanceller.call(
          group_id: group.id,
          payment_id: cancellation_report.id,
          actor_user_id: receiver.id,
          reason: "não recebido",
          idempotency_key: SecureRandom.uuid
        )

        raise "o cancelamento não restaurou o plano" unless SettlementPlanGenerator.call(group.reload) == plan_before_cancellation_report
        raise "o cancelamento alterou o ledger oficial" unless GroupBalanceCalculator.call(group) == official_after_confirmation
      end
    end
  end

  it "detects a spec-only control that omits the confirmed-payment ledger delta" do
    seed = 280_808
    payment = Struct.new(:from_user_id, :to_user_id, :amount_cents).new("sender", "receiver", 1)

    expect do
      Pbt.assert(num_runs: 10, worker: :none, seed:) do
        Pbt.property(Pbt.integer(min: 1, max: 10_000)) do |amount_cents|
          official_before = { "sender" => -amount_cents, "receiver" => amount_cents }
          defective_after = balances_without_confirmation_delta(official_before, payment)

          assert_exact_confirmation_delta!(
            official_before:,
            official_after: defective_after,
            payment:
          )
        end
      end
    end.to raise_error(Pbt::PropertyFailure) { |error|
      expect(error.message).to include("seed: #{seed}")
      expect(error.message).to include("counterexample:")
      expect(error.message).to match(/Shrunk \d+ time/)
      expect(error.message).to include("a confirmação não aplicou os deltas exatos no ledger oficial")
    }
  end
end
