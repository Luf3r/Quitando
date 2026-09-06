class GroupDashboardQuery
  VisualizationNode = Data.define(:user_id, :short_label, :full_name, :position)
  VisualizationEdge = Data.define(:from_user_id, :to_user_id, :amount_cents, :formatted_amount)
  VisualizationMetric = Data.define(:layer, :count, :period, :denominator)
  VisualizationPayload = Data.define(:nodes, :historical, :bilateral, :plan, :metrics, :mode, :initial_layer) do
    def as_json(*)
      {
        nodes: nodes.map(&:to_h),
        layers: {
          historical: historical.map { |edge| edge_json(edge) },
          bilateral: bilateral.map { |edge| edge_json(edge) },
          plan: plan.map { |edge| edge_json(edge) }
        },
        metrics: metrics.map(&:to_h),
        mode:,
        initial_layer:
      }
    end

    private

    def edge_json(edge)
      edge.to_h.merge(amount_cents: edge.amount_cents.to_s)
    end
  end
  Snapshot = Data.define(
    :official_balances,
    :projected_balances,
    :pending_payments,
    :settlement_plan,
    :settlement_trace,
    :visualization,
    :memberships,
    :participant_names,
    :status
  )

  def self.call(group:, viewer:)
    new(group:, viewer:).call
  end

  def initialize(group:, viewer:)
    @group = group
    @viewer = viewer
  end

  def call
    group.with_lock { build_snapshot }
  end

  private

  attr_reader :group, :viewer

  def build_snapshot
    official_balances = GroupBalanceCalculator.call(group)
    pending_payments = group.payments.reported.to_a
    projected_balances = ProjectedBalanceCalculator.call(official_balances, pending_payments)
    settlement_result = DebtSimplifier.new(projected_balances).call_with_trace
    obligations = ObligationGraphBuilder.call(group)
    all_memberships = group.memberships.includes(:user).order(:position, :user_id).to_a

    Snapshot.new(
      official_balances:,
      projected_balances:,
      pending_payments:,
      settlement_plan: settlement_result.transfers,
      settlement_trace: settlement_result.trace,
      visualization: visualization_payload(all_memberships, obligations, settlement_result.transfers),
      memberships: all_memberships.select(&:active?),
      participant_names: all_memberships.index_by(&:user_id).transform_values { |membership| membership.user.name },
      status: GroupFinancialStatusResolver.call(group)
    )
  end

  def visualization_payload(memberships, obligations, settlement_plan)
    layers = {
      historical: visualization_edges(obligations.expense_obligations),
      bilateral: visualization_edges(obligations.bilateral_obligations),
      plan: visualization_edges(settlement_plan)
    }

    VisualizationPayload.new(
      nodes: memberships.map do |membership|
        VisualizationNode.new(
          user_id: membership.user_id,
          short_label: short_label(membership.user.name),
          full_name: membership.user.name,
          position: membership.position
        )
      end,
      historical: layers.fetch(:historical),
      bilateral: layers.fetch(:bilateral),
      plan: layers.fetch(:plan),
      metrics: visualization_metrics(layers),
      mode: group.payments.exists? ? :historical_only : :initial_comparison,
      initial_layer: %i[plan bilateral historical].find { |layer| layers.fetch(layer).any? }
    )
  end

  def short_label(name)
    first_name, second_name = name.split
    return first_name.grapheme_clusters.first(18).join unless second_name

    "#{first_name.grapheme_clusters.first(15).join} #{second_name.grapheme_clusters.first}."
  end

  def visualization_edges(edges)
    edges.map do |edge|
      VisualizationEdge.new(
        from_user_id: edge.from_user_id,
        to_user_id: edge.to_user_id,
        amount_cents: edge.amount_cents,
        formatted_amount: MoneyFormatter.call(cents: edge.amount_cents, currency_code: group.currency_code)
      )
    end
  end

  def visualization_metrics(layers)
    [
      VisualizationMetric.new(
        layer: :historical,
        count: layers.fetch(:historical).length,
        period: :all_recorded_expenses,
        denominator: :aggregated_directional_relations
      ),
      VisualizationMetric.new(
        layer: :bilateral,
        count: layers.fetch(:bilateral).length,
        period: :all_recorded_expenses,
        denominator: :bilateral_net_relations
      ),
      VisualizationMetric.new(
        layer: :plan,
        count: layers.fetch(:plan).length,
        period: :current_projected_balances,
        denominator: :suggested_transfers
      )
    ]
  end
end
