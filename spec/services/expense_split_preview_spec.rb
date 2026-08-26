require "rails_helper"

RSpec.describe ExpenseSplitPreview do
  it "calcula shares iguais com residual determinístico sem persistir" do
    ana = create(:user)
    bruno = create(:user)
    group = GroupCreator.call(owner_user_id: ana.id, name: "Casa")
    create(:membership, group:, user: bruno, position: 1)
    memberships = group.memberships.active.order(:position).to_a

    result = described_class.call(
      amount_text: "10,01", split_type: "equal", memberships:, paid_by_user_id: ana.id,
      participant_user_ids: memberships.map(&:user_id)
    )

    expect(result.amount_cents).to eq(1001)
    expect(result.shares).to eq([ { user_id: ana.id, amount_owed_cents: 501 }, { user_id: bruno.id, amount_owed_cents: 500 } ])
    expect(Expense.count).to eq(0)
  end

  it "rejeita shares exatas que não somam o total" do
    membership = Struct.new(:user_id, :position).new("ana", 0)

    expect {
      described_class.call(amount_text: "10,00", split_type: "exact", memberships: [ membership ], paid_by_user_id: "ana", shares: [ { user_id: "ana", amount_text: "9,99" } ])
    }.to raise_error(described_class::InvalidPreview, "shares devem somar o total")
  end
end
