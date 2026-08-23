require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  WardenSession = Struct.new(:authenticated_user) do
    def user
      authenticated_user
    end
  end

  let(:user) { create(:user) }

  it "identifies the connection from the Devise Warden session" do
    connect env: { "warden" => WardenSession.new(user) }

    expect(connection.current_user).to eq(user)
  end

  it "rejects an anonymous connection" do
    expect { connect env: { "warden" => WardenSession.new(nil) } }.to have_rejected_connection
  end
end
