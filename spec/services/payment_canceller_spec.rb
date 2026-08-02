require "rails_helper"

RSpec.describe PaymentCanceller do
  it "cancels a reported payment for either participant and records its normalized reason" do
    group = create(:group, financial_state_version: 1)
    receiver = create(:user)
    sender = create(:user)
    create(:membership, group:, user: receiver, position: 0)
    create(:membership, group:, user: sender, position: 1)
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    result = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "  não enviado  ", idempotency_key: SecureRandom.uuid)

    expect(result).to be_cancelled
    expect(result.cancellation_reason).to eq("não enviado")
    expect(result.cancelled_by_user_id).to eq(sender.id)
    expect(group.reload.financial_state_version).to eq(2)
  end

  it "returns the terminal payment for an identical cancellation retry" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    key = SecureRandom.uuid
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.cancelled") { |event| events << event.payload }

    original = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: key)
    retried = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: " não enviado ", idempotency_key: key)

    expect(retried.id).to eq(original.id)
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:, command_type: :cancel).count).to eq(1)
    expect(events).to contain_exactly(include(payment_id: payment.id, group_id: group.id, actor_user_id: sender.id, financial_state_version: 1))
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "does not reopen a confirmed payment" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, :confirmed, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    expect do
      described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "erro", idempotency_key: SecureRandom.uuid)
    end.to raise_error(PaymentCommand::InvalidTransition) { |error| expect(error.status).to eq("confirmed") }
  end

  it "rejects an empty cancellation reason before opening a transaction" do
    expect(Group).not_to receive(:transaction)

    expect do
      described_class.call(
        group_id: "019fc36d-c4dd-70b9-bebb-0cda867f7044",
        payment_id: "019fc36d-c4dd-70b9-bebb-0cda867f7045",
        actor_user_id: "019fc36d-c4dd-70b9-bebb-0cda867f7046",
        reason: " \n ",
        idempotency_key: SecureRandom.uuid
      )
    end.to raise_error(PaymentCommand::InvalidInput, "motivo inválido")
  end

  it "permits the receiver to cancel a reported payment" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    result = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, reason: "não recebido", idempotency_key: SecureRandom.uuid)

    expect(result).to be_cancelled
    expect(result.cancelled_by_user_id).to eq(receiver.id)
    expect(result.cancellation_reason).to eq("não recebido")
    expect(group.reload.financial_state_version).to eq(1)
  end

  it "rejects an active third party without changing the reported payment" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    third_party = create(:user)
    [ receiver, sender, third_party ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    expect do
      described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: third_party.id, reason: "não recebido", idempotency_key: SecureRandom.uuid)
    end.to raise_error(PaymentCommand::Forbidden)

    expect(payment.reload).to be_reported
    expect(group.reload.financial_state_version).to eq(0)
    expect(PaymentCommandReceipt.where(payment:, command_type: :cancel)).to be_empty
  end

  it "restores the exact remaining plan after cancelling a partial report" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 2), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })
    full_plan = [ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 300) ]
    payment = PaymentReporter.call(group_id: group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "1,00", expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)

    expect(SettlementPlanGenerator.call(group.reload)).to eq(
      [ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 200) ]
    )

    described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, reason: "não recebido", idempotency_key: SecureRandom.uuid)

    expect(payment.reload).to be_cancelled
    expect(SettlementPlanGenerator.call(group.reload)).to eq(full_plan)
  end
end

RSpec.describe "PaymentCanceller post-commit events", :non_transactional do
  self.use_transactional_tests = false

  it "publishes the cancellation only after an outer transaction commits with its minimal payload" do
    group, receiver, sender, payment = cancellable_payment
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.cancelled") { |event| events << event.payload }

    Group.transaction do
      PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: SecureRandom.uuid)

      expect(events).to be_empty
    end

    expect(events).to contain_exactly(
      payment_id: payment.id,
      group_id: group.id,
      actor_user_id: sender.id,
      financial_state_version: 1
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_payment_event_records(group, receiver, sender)
  end

  it "does not publish the cancellation when an outer transaction rolls back" do
    group, receiver, sender, payment = cancellable_payment
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.cancelled") { |event| events << event.payload }

    Group.transaction do
      PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: SecureRandom.uuid)

      expect(events).to be_empty
      raise ActiveRecord::Rollback
    end

    expect(events).to be_empty
    expect(payment.reload).to be_reported
    expect(group.reload.financial_state_version).to eq(0)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_payment_event_records(group, receiver, sender)
  end

  it "keeps a committed cancellation when its event consumer fails" do
    group, receiver, sender, payment = cancellable_payment
    reports = []
    error_subscriber = Object.new
    error_subscriber.define_singleton_method(:report) do |error, handled:, severity:, context:, source:|
      reports << { error:, handled:, severity:, context:, source: }
    end
    Rails.error.subscribe(error_subscriber)
    observed_state = nil
    event_subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.cancelled") do
      observation = Queue.new
      observer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          observed_payment = Payment.find_by!(id: payment.id)
          observed_group = Group.find_by!(id: group.id)
          observation << { payment_status: observed_payment.status, financial_state_version: observed_group.financial_state_version }
        end
      rescue StandardError => error
        observation << error
      end
      unless observer.join(5)
        observer.kill
        observer.join(5)
        raise "observer thread timed out"
      end

      observed_state = observation.pop
      raise observed_state if observed_state.is_a?(StandardError)

      raise "consumer failure"
    end

    result = PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: SecureRandom.uuid)

    expect(result).to be_cancelled
    expect(payment.reload).to be_cancelled
    expect(group.reload.financial_state_version).to eq(1)
    expect(observed_state).to eq(payment_status: "cancelled", financial_state_version: 1)
    expect(reports).to contain_exactly(
      include(
        error: have_attributes(message: "consumer failure"),
        handled: true,
        severity: :error,
        context: include(payment_id: payment.id, group_id: group.id),
        source: "quitando.payment.cancelled"
      )
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(event_subscriber) if event_subscriber
    Rails.error.unsubscribe(error_subscriber) if error_subscriber
    cleanup_payment_event_records(group, receiver, sender)
  end

  private

  def cancellable_payment
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    [ group, receiver, sender, payment ]
  end

  def cleanup_payment_event_records(group, receiver, sender)
    return unless group&.persisted?

    delete_payment_command_receipts_for_cleanup!(PaymentCommandReceipt.where(payment_id: Payment.where(group_id: group.id).select(:id)))
    Payment.where(group_id: group.id).delete_all
    Membership.where(group_id: group.id).delete_all
    Group.where(id: group.id).delete_all
    User.where(id: [ receiver, sender ].compact.map(&:id)).delete_all
  end
end
