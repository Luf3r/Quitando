class GroupListQuery
  Card = Data.define(
    :group,
    :memberships,
    :status,
    :viewer_balance_cents,
    :pending_payment_count,
    :pending_received_count,
    :pending_sent_count,
    :pending_other_count,
    :attention_rank,
    :archived
  )

  def self.call(groups:, viewer:)
    new(groups:, viewer:).call
  end

  def initialize(groups:, viewer:)
    @groups = groups
    @viewer = viewer
  end

  def call
    groups.includes(memberships: :user).map { |group| card_for(group) }
      .sort_by { |card| [ card.attention_rank, -card.group.updated_at.to_f, card.group.id ] }
  end

  private

  attr_reader :groups, :viewer

  def card_for(group)
    memberships = group.memberships.sort_by { |membership| [ membership.position, membership.user_id ] }
    balances = GroupBalanceCalculator.call(group)
    status = GroupFinancialStatusResolver.call(group)
    pending_payments = group.payments.reported
    pending_received_count = pending_payments.where(to_user_id: viewer.id).count
    pending_sent_count = pending_payments.where(from_user_id: viewer.id).count
    pending_other_count = pending_payments.where.not(from_user_id: viewer.id).where.not(to_user_id: viewer.id).count
    archived = group.archived_at?

    Card.new(
      group:,
      memberships: memberships.select(&:active?),
      status:,
      viewer_balance_cents: balances.fetch(viewer.id, 0),
      pending_payment_count: pending_received_count + pending_sent_count,
      pending_received_count:,
      pending_sent_count:,
      pending_other_count:,
      attention_rank: attention_rank_for(
        archived:,
        pending_received_count:,
        pending_sent_count:,
        viewer_balance_cents: balances.fetch(viewer.id, 0),
        status:
      ),
      archived:
    )
  end

  def attention_rank_for(archived:, pending_received_count:, pending_sent_count:, viewer_balance_cents:, status:)
    return 7 if archived
    return 1 if pending_received_count.positive?
    return 2 if pending_sent_count.positive?
    return 3 if viewer_balance_cents.nonzero?
    return 4 if status.in?([ :open, :awaiting_confirmation ])
    return 5 if status == :empty

    6
  end
end
