require "rails_helper"

RSpec.describe ExpenseWriter do
  describe ".call" do
    it "persiste a despesa e a divisão validada sem controlar a versão financeira" do
      group = create(:group)
      creator = create(:user)
      payer = create(:user)
      participant = create(:user)
      [ creator, payer, participant ].each_with_index do |user, position|
        create(:membership, group:, user:, role: user == creator ? :owner : :member, position:)
      end

      expense = described_class.call(
        group:,
        created_by_user_id: creator.id,
        paid_by_user_id: payer.id,
        description: "Mercado",
        occurred_on: Date.new(2026, 8, 7),
        amount_text: "10,01",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] },
        invalid_expense_class: ExpenseCreator::InvalidExpense
      )

      expect(expense).to have_attributes(
        group_id: group.id,
        created_by_user_id: creator.id,
        paid_by_user_id: payer.id,
        amount_cents: 1_001
      )
      expect(expense.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents, :position)).to eq(
        [ [ payer.id, 501, 0 ], [ participant.id, 500, 1 ] ]
      )
      expect(group.reload.financial_state_version).to eq(0)
    end
  end
end
