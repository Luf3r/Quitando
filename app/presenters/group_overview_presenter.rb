class GroupOverviewPresenter
  PendingPayment = Data.define(:payment, :direction)
  Participant = Data.define(:user_id, :name, :official_cents, :projected_cents, :show_projection)

  def initialize(snapshot:, viewer_id:, archived:)
    @snapshot = snapshot
    @viewer_id = viewer_id
    @archived = archived
  end

  def primary_action
    return :archived if archived
    return :review_received if received_pending.any?
    return :follow_sent if sent_pending.any?
    return :report_transfer if viewer_transfer
    return :add_expense if snapshot.status == :empty
    return :settled if snapshot.status == :settled

    :wait_for_others
  end

  def personal_pending
    received_pending.map { |payment| PendingPayment.new(payment:, direction: :received) }
  end

  def waiting_pending
    snapshot.pending_payments.reject { |payment| payment.to_user_id == viewer_id }.map do |payment|
      direction = payment.from_user_id == viewer_id ? :sent : :other
      PendingPayment.new(payment:, direction:)
    end
  end

  def viewer_official_cents
    snapshot.official_balances.fetch(viewer_id, 0)
  end

  def viewer_projected_cents
    snapshot.projected_balances.fetch(viewer_id, 0)
  end

  def show_viewer_projection?
    viewer_official_cents != viewer_projected_cents
  end

  def participants
    snapshot.participant_names.map do |user_id, name|
      official_cents = snapshot.official_balances.fetch(user_id, 0)
      projected_cents = snapshot.projected_balances.fetch(user_id, 0)
      Participant.new(
        user_id:,
        name:,
        official_cents:,
        projected_cents:,
        show_projection: official_cents != projected_cents
      )
    end
  end

  def viewer_transfer
    snapshot.settlement_plan.find { |transfer| transfer.from_user_id == viewer_id }
  end

  private

  attr_reader :snapshot, :viewer_id, :archived

  def received_pending
    snapshot.pending_payments.select { |payment| payment.to_user_id == viewer_id }
  end

  def sent_pending
    snapshot.pending_payments.select { |payment| payment.from_user_id == viewer_id }
  end
end
