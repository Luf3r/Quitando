require "rails_helper"

RSpec.describe GroupOverviewQuery do
  it "compõe o resumo leve sem depender do grafo histórico" do
    group = create(:group)
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    create(:membership, group:, user: ana, role: :owner, position: 0)
    create(:membership, group:, user: bruno, position: 1)
    expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 300)
    create(:expense_share, expense:, user: bruno, amount_owed_cents: 300, position: 0)

    allow(ObligationGraphBuilder).to receive(:call).and_raise("o Resumo não compõe o grafo")

    snapshot = described_class.call(group:, viewer: ana)

    expect(snapshot.official_balances).to eq(ana.id => 300, bruno.id => -300)
    expect(snapshot.projected_balances).to eq(snapshot.official_balances)
    expect(snapshot.settlement_plan).to contain_exactly(
      an_object_having_attributes(from_user_id: bruno.id, to_user_id: ana.id, amount_cents: 300)
    )
    expect(snapshot).not_to respond_to(:visualization)
    expect(snapshot).not_to respond_to(:settlement_trace)
  end
end
