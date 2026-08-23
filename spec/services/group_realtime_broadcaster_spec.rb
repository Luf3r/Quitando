require "rails_helper"

RSpec.describe GroupRealtimeBroadcaster do
  let(:payload) { { group_id: SecureRandom.uuid, actor_user_id: SecureRandom.uuid, change_type: :expense_created, financial_state_version: 3 } }

  it "broadcasts only safe notice text and a Turbo refresh to the group stream" do
    allow(ActionCable.server).to receive(:broadcast)
    allow(Turbo).to receive(:current_request_id).and_return("request-123")

    described_class.call(payload)

    expect(ActionCable.server).to have_received(:broadcast).with(
      payload[:group_id],
      include("O estado do grupo foi atualizado.", 'action="refresh"', 'request-id="request-123"')
    )
  end

  it "reports its own delivery failure and returns normally" do
    allow(ActionCable.server).to receive(:broadcast).and_raise(StandardError, "cable unavailable")
    reports = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **context| reports << [ error, context ] }
    Rails.error.subscribe(subscriber)

    expect { described_class.call(payload) }.not_to raise_error
    expect(reports).to contain_exactly(include(an_instance_of(StandardError), include(handled: true, source: "quitando.group.state_changed")))
  ensure
    Rails.error.unsubscribe(subscriber) if subscriber
  end

  it "reconnects the affected user's cable connections only after commit" do
    user = create(:user)
    remote_connections = double("remote connections", disconnect: nil)
    allow(ActionCable.server).to receive(:remote_connections).and_return(remote_connections)
    allow(remote_connections).to receive(:where).with(current_user: user).and_return(remote_connections)

    Group.transaction do
      described_class.schedule_reconnection(user.id)
      expect(remote_connections).not_to have_received(:disconnect)
    end

    expect(remote_connections).to have_received(:disconnect).with(reconnect: true)
  end
end
