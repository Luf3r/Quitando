require "rails_helper"

RSpec.describe PaymentConfirmer do
  it "confirms a reported payment only once for its receiver" do
    group = create(:group, financial_state_version: 1)
    receiver = create(:user)
    sender = create(:user)
    create(:membership, group:, user: receiver, position: 0)
    create(:membership, group:, user: sender, position: 1)
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    result = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)

    expect(result).to be_confirmed
    expect(result.confirmed_by_user_id).to eq(receiver.id)
    expect(group.reload.financial_state_version).to eq(2)
    expect(GroupBalanceCalculator.call(group)).to eq(receiver.id => -100, sender.id => 100)
  end

  it "returns the terminal payment for an identical confirmation retry" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    key = SecureRandom.uuid
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.confirmed") { |event| events << event.payload }

    original = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: key)
    retried = described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: key)

    expect(retried.id).to eq(original.id)
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:, command_type: :confirm).count).to eq(1)
    expect(events).to contain_exactly(include(payment_id: payment.id, group_id: group.id, actor_user_id: receiver.id, financial_state_version: 1))
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "rejects a retry key with a different confirmation payload" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    other_receiver = create(:user)
    [ receiver, sender, other_receiver ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    key = SecureRandom.uuid
    described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: key)

    expect do
      described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: other_receiver.id, idempotency_key: key)
    end.to raise_error(PaymentCommand::IdempotencyConflict)
  end

  it "rejects a key already used by a report command" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    key = SecureRandom.uuid
    PaymentCommandReceipt.create!(payment:, command_type: :report, idempotency_key: key, request_fingerprint: "report-fingerprint")

    expect do
      described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: key)
    end.to raise_error(PaymentCommand::IdempotencyConflict)
  end

  it "rejects an archived group without changing the payment" do
    group = create(:group, archived_at: Time.current)
    receiver = create(:user)
    sender = create(:user)
    third_party = create(:user)
    [ receiver, sender, third_party ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    expect { described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: third_party.id, idempotency_key: SecureRandom.uuid) }.to raise_error(PaymentCommand::ArchivedGroup)
    expect(payment.reload).to be_reported
    expect(group.reload.financial_state_version).to eq(0)
  end

  it "rejects an active third party without changing the reported payment" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    third_party = create(:user)
    [ receiver, sender, third_party ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)

    expect do
      described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: third_party.id, idempotency_key: SecureRandom.uuid)
    end.to raise_error(PaymentCommand::Forbidden)

    expect(payment.reload).to be_reported
    expect(group.reload.financial_state_version).to eq(0)
    expect(PaymentCommandReceipt.where(payment:, command_type: :confirm)).to be_empty
  end

  it "rejects a terminal payment when called with a fresh key" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)

    expect do
      described_class.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)
    end.to raise_error(PaymentCommand::InvalidTransition) { |error| expect(error.status).to eq("confirmed") }

    expect(payment.reload).to be_confirmed
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:, command_type: :confirm).count).to eq(1)
  end
end

RSpec.describe "PaymentConfirmer post-commit events", :non_transactional do
  self.use_transactional_tests = false

  it "publishes the confirmation only after an outer transaction commits with its minimal payload" do
    group, receiver, sender, payment = confirmable_payment
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.confirmed") { |event| events << event.payload }

    Group.transaction do
      PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)

      expect(events).to be_empty
    end

    expect(events).to contain_exactly(
      payment_id: payment.id,
      group_id: group.id,
      actor_user_id: receiver.id,
      financial_state_version: 1
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_payment_event_records(group, receiver, sender)
  end

  it "does not publish the confirmation when an outer transaction rolls back" do
    group, receiver, sender, payment = confirmable_payment
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.confirmed") { |event| events << event.payload }

    Group.transaction do
      PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)

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

  it "keeps a committed confirmation when its event consumer fails" do
    group, receiver, sender, payment = confirmable_payment
    reports = []
    error_subscriber = Object.new
    error_subscriber.define_singleton_method(:report) do |error, handled:, severity:, context:, source:|
      reports << { error:, handled:, severity:, context:, source: }
    end
    Rails.error.subscribe(error_subscriber)
    observed_state = nil
    event_subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.confirmed") do
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

    result = PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)

    expect(result).to be_confirmed
    expect(payment.reload).to be_confirmed
    expect(group.reload.financial_state_version).to eq(1)
    expect(observed_state).to eq(payment_status: "confirmed", financial_state_version: 1)
    expect(reports).to contain_exactly(
      include(
        error: have_attributes(message: "consumer failure"),
        handled: true,
        severity: :error,
        context: include(payment_id: payment.id, group_id: group.id),
        source: "quitando.payment.confirmed"
      )
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(event_subscriber) if event_subscriber
    Rails.error.unsubscribe(error_subscriber) if error_subscriber
    cleanup_payment_event_records(group, receiver, sender)
  end

  private

  def confirmable_payment
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
