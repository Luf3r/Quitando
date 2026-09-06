require "rails_helper"

RSpec.describe GroupDashboardQuery do
  it "entrega nomes completos e rótulos curtos por grafema sem expor e-mails", :aggregate_failures do
    group = create(:group)
    names = [ "Ágata Évora Silva", "João", "A\u0301" * 20 + " Oliveira" ]
    users = names.each_with_index.map do |name, position|
      create(:user, name:).tap { |user| create(:membership, group:, user:, position:) }
    end

    snapshot = described_class.call(group:, viewer: users.first)

    expect(snapshot.to_h).to include(participant_names: users.index_by(&:id).transform_values(&:name))
    expect(snapshot.visualization.as_json.fetch(:nodes)).to eq([
      { user_id: users[0].id, short_label: "Ágata É.", full_name: names[0], position: 0 },
      { user_id: users[1].id, short_label: "João", full_name: names[1], position: 1 },
      { user_id: users[2].id, short_label: "A\u0301" * 15 + " O.", full_name: names[2], position: 2 }
    ])
    expect(snapshot.visualization.to_json).not_to include(*users.map(&:email))
  end

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


  it "compõe trace e payload tipado das três camadas a partir do mesmo snapshot" do
    group = create(:group)
    owner = create(:user, name: "Ana", email: "ana@example.com")
    member = create(:user, name: "Bruno", email: "bruno@example.com")
    create(:membership, group:, user: owner, role: :owner, position: 0)
    create(:membership, group:, user: member, position: 1)
    expense = create(
      :expense,
      group:,
      paid_by_user: owner,
      created_by_user: member,
      amount_cents: 300
    )
    create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)

    snapshot = described_class.call(group:, viewer: owner)
    edge = described_class::VisualizationEdge.new(
      from_user_id: member.id,
      to_user_id: owner.id,
      amount_cents: 300,
      formatted_amount: "R$ 3,00"
    )

    expect(snapshot.settlement_trace).to contain_exactly(
      an_object_having_attributes(from_user_id: member.id, to_user_id: owner.id, amount_cents: 300)
    )
    expect(snapshot.visualization).to eq(
      described_class::VisualizationPayload.new(
        nodes: [
          described_class::VisualizationNode.new(user_id: owner.id, short_label: "Ana", full_name: "Ana", position: 0),
          described_class::VisualizationNode.new(user_id: member.id, short_label: "Bruno", full_name: "Bruno", position: 1)
        ],
        historical: [ edge ],
        bilateral: [ edge ],
        plan: [ edge ],
        metrics: [
          described_class::VisualizationMetric.new(
            layer: :historical,
            count: 1,
            period: :all_recorded_expenses,
            denominator: :aggregated_directional_relations
          ),
          described_class::VisualizationMetric.new(
            layer: :bilateral,
            count: 1,
            period: :all_recorded_expenses,
            denominator: :bilateral_net_relations
          ),
          described_class::VisualizationMetric.new(
            layer: :plan,
            count: 1,
            period: :current_projected_balances,
            denominator: :suggested_transfers
          )
        ],
        mode: :initial_comparison,
        initial_layer: :plan
      )
    )
    expect(snapshot.visualization.plan.first.amount_cents).to eq(300)
    expect(snapshot.visualization.as_json.dig(:layers, :plan, 0, :amount_cents)).to eq("300")
  end


  it "usa modo histórico depois de pagamento reportado, confirmado ou cancelado" do
    %i[reported confirmed cancelled].each do |status|
      group = create(:group)
      from_user = create(:user)
      to_user = create(:user)
      create(:membership, group:, user: from_user, role: :owner, position: 0)
      create(:membership, group:, user: to_user, position: 1)
      payment_factory_traits = status == :reported ? [] : [ status ]
      create(:payment, *payment_factory_traits, group:, from_user:, to_user:)

      snapshot = described_class.call(group:, viewer: from_user)

      expect(snapshot.visualization.mode).to eq(:historical_only)
      expect(snapshot.visualization.metrics.map(&:period)).to eq(
        %i[all_recorded_expenses all_recorded_expenses current_projected_balances]
      )
      expect(snapshot.visualization.metrics.map(&:denominator)).to eq(
        %i[aggregated_directional_relations bilateral_net_relations suggested_transfers]
      )
    end
  end


  it "inclui membership inativa com posição estável quando ela faz parte do histórico" do
    group = create(:group)
    owner = create(:user)
    inactive_member = create(:user)
    create(:membership, group:, user: owner, role: :owner, position: 0)
    create(:membership, group:, user: inactive_member, status: :inactive, position: 1)
    expense = create(:expense, group:, paid_by_user: owner, created_by_user: owner, amount_cents: 100)
    create(:expense_share, expense:, user: inactive_member, amount_owed_cents: 100, position: 0)

    snapshot = described_class.call(group:, viewer: owner)

    expect(snapshot.memberships.map(&:user_id)).to eq([ owner.id ])
    expect(snapshot.visualization.nodes.map { |node| [ node.user_id, node.position ] }).to eq(
      [ [ owner.id, 0 ], [ inactive_member.id, 1 ] ]
    )
  end
end
