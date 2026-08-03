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

    def create_two_member_group
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      [ group, ana, bruno ]
    end
  end
end
