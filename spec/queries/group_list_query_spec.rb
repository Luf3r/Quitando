require "rails_helper"

RSpec.describe GroupListQuery do
  it "compõe cards sem executar o simplificador" do
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    group = GroupCreator.call(owner_user_id: ana.id, name: "Apartamento")
    create(:membership, group:, user: bruno, position: 1)

    expect(DebtSimplifier).not_to receive(:new)

    cards = described_class.call(groups: Group.where(id: group.id), viewer: ana)

    expect(cards).to contain_exactly(
      have_attributes(
        group:,
        memberships: contain_exactly(have_attributes(user: ana), have_attributes(user: bruno)),
        status: :empty,
        viewer_balance_cents: 0,
        pending_payment_count: 0,
        archived: false
      )
    )
  end
end
