require "rails_helper"

RSpec.describe GroupDashboardQuery do
  it "compõe saldos e plano sem persistir estado" do
    group = create(:group, financial_state_version: 4)
    owner = create(:user)
    member = create(:user)
    create(:membership, group:, user: owner, role: :owner, position: 0)
    create(:membership, group:, user: member, position: 1)

    snapshot = described_class.call(group:, viewer: owner)

    expect(snapshot.official_balances).to eq(owner.id => 0, member.id => 0)
    expect(snapshot.projected_balances).to eq(snapshot.official_balances)
    expect(snapshot.pending_payments).to be_empty
    expect(snapshot.settlement_plan).to be_empty
    expect(group.reload.financial_state_version).to eq(4)
  end
end
