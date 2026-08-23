require "rails_helper"

RSpec.describe GroupsChannel, type: :channel do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let!(:membership) { create(:membership, group:, user:) }

  def signed_stream_name(stream_name)
    Turbo::StreamsChannel.signed_stream_name(stream_name)
  end

  it "subscribes an active member to its signed group stream" do
    stub_connection(current_user: user)

    subscribe signed_stream_name: signed_stream_name(group.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(group.id)
  end

  it "rejects an unsigned or altered stream before querying groups" do
    stub_connection(current_user: user)

    expect(Group).not_to receive(:find_by)
    subscribe signed_stream_name: "altered-stream"

    expect(subscription).to be_rejected
    expect(subscription.streams).to be_empty
  end

  it "rejects a signed non-canonical group identifier before querying groups" do
    stub_connection(current_user: user)

    expect(Group).not_to receive(:find_by)
    subscribe signed_stream_name: signed_stream_name(group.id.upcase)

    expect(subscription).to be_rejected
    expect(subscription.streams).to be_empty
  end

  it "rejects a member trying to subscribe to another group" do
    other_group = create(:group)
    stub_connection(current_user: user)

    subscribe signed_stream_name: signed_stream_name(other_group.id)

    expect(subscription).to be_rejected
    expect(subscription.streams).to be_empty
  end

  it "rejects a user whose membership is inactive" do
    membership.update!(status: :inactive)
    stub_connection(current_user: user)

    subscribe signed_stream_name: signed_stream_name(group.id)

    expect(subscription).to be_rejected
    expect(subscription.streams).to be_empty
  end

  it "rejects an anonymous channel subscription before querying groups" do
    stub_connection(current_user: nil)

    expect(Group).not_to receive(:find_by)
    subscribe signed_stream_name: signed_stream_name(group.id)

    expect(subscription).to be_rejected
    expect(subscription.streams).to be_empty
  end
end
