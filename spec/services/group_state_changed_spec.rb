require "rails_helper"

RSpec.describe GroupStateChanged, :non_transactional do
  self.use_transactional_tests = false

  it "emits its minimal event only after the outer transaction commits" do
    group = create(:group)
    actor = create(:user)
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(described_class::EVENT_NAME) { |event| events << event.payload }

    Group.transaction do
      described_class.publish(group_id: group.id, actor_user_id: actor.id, change_type: :expense_created, financial_state_version: 4)
      expect(events).to be_empty
    end

    expect(events).to eq([ { group_id: group.id, actor_user_id: actor.id, change_type: :expense_created, financial_state_version: 4 } ])
    expect(events.first).not_to include(:description, :amount_cents, :idempotency_key, :token, :form)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "does not emit after an outer rollback" do
    group = create(:group)
    actor = create(:user)
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(described_class::EVENT_NAME) { |event| events << event.payload }

    Group.transaction do
      described_class.publish(group_id: group.id, actor_user_id: actor.id, change_type: :payment_reported, financial_state_version: 5)
      raise ActiveRecord::Rollback
    end

    expect(events).to be_empty
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "rejects a change type outside its closed map" do
    expect do
      described_class.publish(group_id: SecureRandom.uuid, actor_user_id: SecureRandom.uuid, change_type: :unknown)
    end.to raise_error(ArgumentError, "tipo de mudança inválido")
  end

  it "keeps persistence confirmed and reports a consumer failure without secret payload fields" do
    group = create(:group)
    actor = create(:user)
    reports = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **context| reports << [ error, context ] }
    Rails.error.subscribe(subscriber)
    failing_listener = ActiveSupport::Notifications.subscribe(described_class::EVENT_NAME) { raise "delivery failed" }

    Group.transaction do
      group.update!(name: "Nome confirmado")
      described_class.publish(group_id: group.id, actor_user_id: actor.id, change_type: :group_renamed)
    end

    expect(group.reload.name).to eq("Nome confirmado")
    expect(reports).to contain_exactly(include(an_instance_of(RuntimeError), include(handled: true, source: described_class::EVENT_NAME, context: { group_id: group.id, actor_user_id: actor.id, change_type: :group_renamed })))
  ensure
    ActiveSupport::Notifications.unsubscribe(failing_listener) if failing_listener
    Rails.error.unsubscribe(subscriber) if subscriber
  end
end
