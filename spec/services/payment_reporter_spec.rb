require "rails_helper"

RSpec.describe PaymentReporter do
  describe ".call" do
    it "rejects malformed persisted identifiers before opening a transaction" do
      expect(Group).not_to receive(:transaction)

      expect do
        described_class.call(
          group_id: "not-a-uuid",
          actor_user_id: SecureRandom.uuid,
          from_user_id: SecureRandom.uuid,
          to_user_id: SecureRandom.uuid,
          amount_text: "1,00",
          expected_financial_state_version: 0,
          idempotency_key: SecureRandom.uuid
        )
      end.to raise_error(PaymentCommand::InvalidInput)
    end

    it "reports a current partial suggestion without changing the official balance" do
      group = create(:group)
      receiver = create(:user)
      sender = create(:user)
      create(:membership, group:, user: receiver, position: 0)
      create(:membership, group:, user: sender, position: 1)
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: receiver.id,
        paid_by_user_id: receiver.id,
        description: "Jantar",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "6,00",
        split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }
      )

      payment = described_class.call(
        group_id: group.id,
        actor_user_id: sender.id,
        from_user_id: sender.id,
        to_user_id: receiver.id,
        amount_text: "1,00",
        expected_financial_state_version: group.reload.financial_state_version,
        idempotency_key: SecureRandom.uuid
      )

      expect(payment).to be_reported
      expect(payment.amount_cents).to eq(100)
      expect(payment.reported_by_user_id).to eq(sender.id)
      expect(group.reload.financial_state_version).to eq(2)
      expect(GroupBalanceCalculator.call(group)).to eq(receiver.id => 300, sender.id => -300)
      expect(SettlementPlanGenerator.call(group)).to eq(
        [ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 200) ]
      )
    end

    it "returns the existing payment for an identical idempotent retry" do
      group = create(:group)
      receiver = create(:user)
      sender = create(:user)
      create(:membership, group:, user: receiver, position: 0)
      create(:membership, group:, user: sender, position: 1)
      ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 2), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })
      key = SecureRandom.uuid
      attributes = { group_id: group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "1,00", expected_financial_state_version: group.reload.financial_state_version, idempotency_key: key }
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.reported") { |event| events << event.payload }

      original = described_class.call(**attributes)
      retried = described_class.call(**attributes)

      expect(retried.id).to eq(original.id)
      expect(PaymentCommandReceipt.where(idempotency_key: key).count).to eq(1)
      expect(group.reload.financial_state_version).to eq(2)
      expect(events).to contain_exactly(include(payment_id: original.id, group_id: group.id, actor_user_id: sender.id, financial_state_version: 2))
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    it "returns the authorized current plan for a stale version without writing" do
      group = create(:group)
      receiver = create(:user)
      sender = create(:user)
      create(:membership, group:, user: receiver, position: 0)
      create(:membership, group:, user: sender, position: 1)
      ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 2), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })

      expect do
        described_class.call(group_id: group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "1,00", expected_financial_state_version: 0, idempotency_key: SecureRandom.uuid)
      end.to raise_error(PaymentCommand::StaleFinancialState) { |error|
        expect(error.financial_state_version).to eq(1)
        expect(error.plan).to eq([ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 300) ])
      }

      expect(Payment.where(group:)).to be_empty
      expect(PaymentCommandReceipt.joins(:payment).where(payments: { group_id: group.id })).to be_empty
      expect(group.reload.financial_state_version).to eq(1)
    end

    it "rejects an actor who is active only in another group" do
      group, receiver, sender = reportable_group
      foreign_group = create(:group)
      foreign_actor = create(:user)
      create(:membership, group: foreign_group, user: foreign_actor)
      expected_version = group.reload.financial_state_version

      expect do
        described_class.call(group_id: group.id, actor_user_id: foreign_actor.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "1,00", expected_financial_state_version: expected_version, idempotency_key: SecureRandom.uuid)
      end.to raise_error(PaymentCommand::Forbidden)

      expect(Payment.where(group:)).to be_empty
      expect(PaymentCommandReceipt.joins(:payment).where(payments: { group_id: group.id })).to be_empty
      expect(group.reload.financial_state_version).to eq(expected_version)
    end

    it "rejects a participant pair absent from the current plan" do
      group, receiver, sender = reportable_group
      expected_version = group.reload.financial_state_version

      expect do
        described_class.call(group_id: group.id, actor_user_id: receiver.id, from_user_id: receiver.id, to_user_id: sender.id, amount_text: "1,00", expected_financial_state_version: expected_version, idempotency_key: SecureRandom.uuid)
      end.to raise_error(PaymentCommand::SuggestionUnavailable)

      expect(Payment.where(group:)).to be_empty
      expect(group.reload.financial_state_version).to eq(expected_version)
    end

    it "rejects an amount above the exact current suggestion" do
      group, receiver, sender = reportable_group
      expected_version = group.reload.financial_state_version

      expect do
        described_class.call(group_id: group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "3,01", expected_financial_state_version: expected_version, idempotency_key: SecureRandom.uuid)
      end.to raise_error(PaymentCommand::SuggestionUnavailable)

      expect(Payment.where(group:)).to be_empty
      expect(group.reload.financial_state_version).to eq(expected_version)
    end

    def reportable_group
      group = create(:group)
      receiver = create(:user)
      sender = create(:user)
      [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      ExpenseCreator.call(
        group_id: group.id,
        created_by_user_id: receiver.id,
        paid_by_user_id: receiver.id,
        description: "Jantar",
        occurred_on: Date.new(2026, 8, 2),
        amount_text: "6,00",
        split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }
      )

      [ group, receiver, sender ]
    end
  end
end

RSpec.describe "PaymentReporter post-commit events", :non_transactional do
  self.use_transactional_tests = false

  it "publishes the report only after an outer transaction commits with its minimal payload" do
    group, receiver, sender = reportable_group
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.reported") { |event| events << event.payload }

    payment = nil
    Group.transaction do
      payment = report_payment(group:, sender:, receiver:)

      expect(events).to be_empty
    end

    expect(events).to contain_exactly(
      payment_id: payment.id,
      group_id: group.id,
      actor_user_id: sender.id,
      financial_state_version: 2
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_reportable_group(group, receiver, sender)
  end

  it "does not publish the report when an outer transaction rolls back" do
    group, receiver, sender = reportable_group
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.reported") { |event| events << event.payload }

    Group.transaction do
      report_payment(group:, sender:, receiver:)

      expect(events).to be_empty
      raise ActiveRecord::Rollback
    end

    expect(events).to be_empty
    expect(Payment.where(group:)).to be_empty
    expect(group.reload.financial_state_version).to eq(1)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_reportable_group(group, receiver, sender)
  end

  it "keeps a committed report when its event consumer fails" do
    group, receiver, sender = reportable_group
    reports = []
    error_subscriber = Object.new
    error_subscriber.define_singleton_method(:report) do |error, handled:, severity:, context:, source:|
      reports << { error:, handled:, severity:, context:, source: }
    end
    Rails.error.subscribe(error_subscriber)
    observed_state = nil
    event_subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.reported") do |event|
      observation = Queue.new
      observer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          observed_payment = Payment.find_by!(id: event.payload.fetch(:payment_id))
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

    payment = report_payment(group:, sender:, receiver:)

    expect(payment).to be_reported
    expect(payment.reload).to be_reported
    expect(group.reload.financial_state_version).to eq(2)
    expect(observed_state).to eq(payment_status: "reported", financial_state_version: 2)
    expect(reports).to contain_exactly(
      include(
        error: have_attributes(message: "consumer failure"),
        handled: true,
        severity: :error,
        context: include(payment_id: payment.id, group_id: group.id),
        source: "quitando.payment.reported"
      )
    )
  ensure
    ActiveSupport::Notifications.unsubscribe(event_subscriber) if event_subscriber
    Rails.error.unsubscribe(error_subscriber) if error_subscriber
    cleanup_reportable_group(group, receiver, sender)
  end

  private

  def reportable_group
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    ExpenseCreator.call(
      group_id: group.id,
      created_by_user_id: receiver.id,
      paid_by_user_id: receiver.id,
      description: "Jantar",
      occurred_on: Date.new(2026, 8, 2),
      amount_text: "6,00",
      split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }
    )

    [ group, receiver, sender ]
  end

  def report_payment(group:, sender:, receiver:)
    PaymentReporter.call(
      group_id: group.id,
      actor_user_id: sender.id,
      from_user_id: sender.id,
      to_user_id: receiver.id,
      amount_text: "1,00",
      expected_financial_state_version: group.reload.financial_state_version,
      idempotency_key: SecureRandom.uuid
    )
  end

  def cleanup_reportable_group(group, receiver, sender)
    return unless group&.persisted?

    delete_payment_command_receipts_for_cleanup!(PaymentCommandReceipt.where(payment_id: Payment.where(group_id: group.id).select(:id)))
    Payment.where(group_id: group.id).delete_all
    delete_expense_history_for_cleanup!(Expense.where(group_id: group.id))
    Membership.where(group_id: group.id).delete_all
    Group.where(id: group.id).delete_all
    User.where(id: [ receiver, sender ].compact.map(&:id)).delete_all
  end
end
