class GroupListQuery
  Card = Data.define(:group, :memberships, :status, :viewer_balance_cents, :pending_payment_count, :archived)

  def self.call(groups:, viewer:)
    new(groups:, viewer:).call
  end

  def initialize(groups:, viewer:)
    @groups = groups
    @viewer = viewer
  end

  def call
    groups.includes(memberships: :user).order(updated_at: :desc).map { |group| card_for(group) }
  end

  private

  attr_reader :groups, :viewer

  def card_for(group)
    memberships = group.memberships.sort_by { |membership| [ membership.position, membership.user_id ] }
    balances = GroupBalanceCalculator.call(group)

    Card.new(
      group:,
      memberships: memberships.select(&:active?),
      status: GroupFinancialStatusResolver.call(group),
      viewer_balance_cents: balances.fetch(viewer.id, 0),
      pending_payment_count: group.payments.reported.where(from_user_id: viewer.id).or(group.payments.reported.where(to_user_id: viewer.id)).count,
      archived: group.archived_at?
    )
  end
end
