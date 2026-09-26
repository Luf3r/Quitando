require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  WardenSession = Struct.new(:authenticated_user) do
    def user
      authenticated_user
    end
  end

  let(:user) { create(:user) }

  it "identifies the connection from the Devise Warden session" do
    connect headers: { "HOST" => "localhost" }, env: { "warden" => WardenSession.new(user) }

    expect(connection.current_user).to eq(user)
  end

  it "seleciona o banco demo antes de resolver a sessão" do
    demo_user = ApplicationRecord.connected_to(role: :writing, shard: :demo) do
      create(:user, email: "cable-demo@example.com")
    end
    session = Object.new
    session.define_singleton_method(:user) { User.find_by!(email: "cable-demo@example.com") }

    connect headers: { "HOST" => "demo.localhost" }, env: { "warden" => session }

    expect(connection.current_user.id).to eq(demo_user.id)
    expect(connection.environment_shard).to eq(:demo)
  end
  it "rejects an anonymous connection" do
    expect { connect headers: { "HOST" => "localhost" }, env: { "warden" => WardenSession.new(nil) } }.to have_rejected_connection
  end
end
