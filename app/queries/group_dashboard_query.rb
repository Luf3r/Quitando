class GroupDashboardQuery
  Snapshot = Data.define(:official_balances, :projected_balances, :pending_payments, :settlement_plan, :memberships, :status)

  def self.call(group:, viewer:)
    new(group:, viewer:).call
  end

  def initialize(group:, viewer:)
    @group = group
    @viewer = viewer
  end

  def call
    official_balances = GroupBalanceCalculator.call(group)
    pending_payments = group.payments.reported.to_a
    projected_balances = ProjectedBalanceCalculator.call(official_balances, pending_payments)

    Snapshot.new(
      official_balances:,
      projected_balances:,
      pending_payments:,
      settlement_plan: DebtSimplifier.new(projected_balances).call,
      memberships: group.memberships.active.includes(:user).order(:position).to_a,
      status: GroupFinancialStatusResolver.call(group)
    )
  end

  private

  attr_reader :group, :viewer
end
