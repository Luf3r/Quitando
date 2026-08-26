class GroupOverviewQuery
  Snapshot = Data.define(
    :official_balances,
    :projected_balances,
    :pending_payments,
    :settlement_plan,
    :memberships,
    :participant_emails,
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
    group.with_lock do
      official_balances = GroupBalanceCalculator.call(group)
      pending_payments = group.payments.reported.includes(:from_user, :to_user).to_a
      projected_balances = ProjectedBalanceCalculator.call(official_balances, pending_payments)
      memberships = group.memberships.includes(:user).order(:position, :user_id).to_a

      Snapshot.new(
        official_balances:,
        projected_balances:,
        pending_payments:,
        settlement_plan: DebtSimplifier.new(projected_balances).call,
        memberships: memberships.select(&:active?),
        participant_emails: memberships.index_by(&:user_id).transform_values { |membership| membership.user.email },
        status: GroupFinancialStatusResolver.call(group)
      )
    end
  end

  private

  attr_reader :group, :viewer
end
