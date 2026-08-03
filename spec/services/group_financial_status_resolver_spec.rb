require "rails_helper"

RSpec.describe "GroupFinancialStatusResolver" do
  describe ".call" do
    it "returns empty for a group without financial activity" do
      group = create(:group)
      user = create(:user)
      create(:membership, group:, user:, position: 0)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:empty)
    end

    it "returns settled for financial activity with zero official balances" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      first_expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
      create(:expense_share, expense: first_expense, user: bruno, amount_owed_cents: 100, position: 0)
      second_expense = create(:expense, group:, paid_by_user: bruno, created_by_user: bruno, amount_cents: 100)
      create(:expense_share, expense: second_expense, user: ana, amount_owed_cents: 100, position: 0)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:settled)
    end

    it "returns open for an active expense with nonzero official balances" do
      group, ana, bruno = create_two_member_group
      expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 100, position: 0)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:open)
    end

    it "returns empty when the history has only a voided expense and a cancelled payment" do
      group, ana, bruno = create_two_member_group
      expense = create(:expense, :voided, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100, voided_by_user: ana)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 100, position: 0)
      create(:payment, :cancelled, group:, from_user: bruno, to_user: ana, amount_cents: 100)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:empty)
    end

    it "returns open for a confirmed payment without an active expense" do
      group, ana, bruno = create_two_member_group
      create(:payment, :confirmed, group:, from_user: bruno, to_user: ana, amount_cents: 100)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:open)
    end

    it "propagates an unbalanced active ledger" do
      group, ana, bruno = create_two_member_group
      expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 99, position: 0)

      expect { GroupFinancialStatusResolver.call(group) }.to raise_error(GroupBalanceCalculator::UnbalancedLedger)
    end

    it "returns awaiting confirmation while a partial report leaves a remaining plan" do
      group, receiver, sender = create_reportable_group
      report_payment(group:, receiver:, sender:, amount_text: "1,00")

      expect(SettlementPlanGenerator.call(group.reload)).to eq(
        [ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 200) ]
      )
      expect(GroupFinancialStatusResolver.call(group)).to eq(:awaiting_confirmation)
    end

    it "returns awaiting confirmation while a total report leaves no remaining plan" do
      group, receiver, sender = create_reportable_group
      report_payment(group:, receiver:, sender:, amount_text: "3,00")

      expect(SettlementPlanGenerator.call(group.reload)).to be_empty
      expect(GroupFinancialStatusResolver.call(group)).to eq(:awaiting_confirmation)
    end

    it "propagates an unbalanced active ledger even when a payment is reported" do
      group, ana, bruno = create_two_member_group
      expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 99, position: 0)
      create(:payment, group:, from_user: bruno, to_user: ana, amount_cents: 1)

      expect { GroupFinancialStatusResolver.call(group) }.to raise_error(GroupBalanceCalculator::UnbalancedLedger)
    end

    it "returns settled after the receiver confirms a total report" do
      group, receiver, sender = create_reportable_group
      payment = report_payment(group:, receiver:, sender:, amount_text: "3,00")
      PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:settled)
    end

    it "returns open after a participant cancels a total report" do
      group, receiver, sender = create_reportable_group
      payment = report_payment(group:, receiver:, sender:, amount_text: "3,00")
      PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "Não enviado", idempotency_key: SecureRandom.uuid)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:open)
    end

    it "keeps the derived status when the group is archived" do
      group, receiver, sender = create_reportable_group
      payment = report_payment(group:, receiver:, sender:, amount_text: "3,00")
      PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)
      group.update!(archived_at: Time.current)

      expect(GroupFinancialStatusResolver.call(group)).to eq(:settled)
    end

    it "does not persist a status or change financial facts while reading" do
      group, _receiver, _sender = create_reportable_group
      snapshot = {
        financial_state_version: group.reload.financial_state_version,
        expense_ids: group.expenses.order(:id).pluck(:id),
        payment_ids: group.payments.order(:id).pluck(:id)
      }

      GroupFinancialStatusResolver.call(group)

      expect(
        financial_state_version: group.reload.financial_state_version,
        expense_ids: group.expenses.order(:id).pluck(:id),
        payment_ids: group.payments.order(:id).pluck(:id)
      ).to eq(snapshot)
    end

    def create_two_member_group
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      [ group, ana, bruno ]
    end

    def create_reportable_group
      group, receiver, sender = create_two_member_group
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: receiver.id,
        paid_by_user_id: receiver.id,
        description: "Jantar",
        occurred_on: Date.new(2026, 8, 3),
        amount_text: "6,00",
        split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }
      )
      [ group, receiver, sender ]
    end

    def report_payment(group:, receiver:, sender:, amount_text:)
      PaymentReporter.call(
        group_id: group.id,
        actor_user_id: sender.id,
        from_user_id: sender.id,
        to_user_id: receiver.id,
        amount_text:,
        expected_financial_state_version: group.reload.financial_state_version,
        idempotency_key: SecureRandom.uuid
      )
    end
  end
end
