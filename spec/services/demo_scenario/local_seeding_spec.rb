require "rails_helper"

RSpec.describe "Seeds locais da demo" do
  it "instala as quatro contas públicas apenas no banco demo" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_LOCAL_DUAL_DATABASE").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("false")
    allow(ENV).to receive(:[]).with("QUITANDO_SEED_LOCAL_DEMO").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_DATABASE_NAME").and_return("quitando_demo_test")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_PASSWORD").and_return("senha-publica")
    real_user = create(:user, email: "real-persistente@example.com")

    load Rails.root.join("db/seeds.rb")

    expect(User.find(real_user.id)).to eq(real_user)
    expect(User.where(demo_account: true)).to be_empty
    ApplicationRecord.connected_to(role: :writing, shard: :demo) do
      expect(User.where(demo_account: true).pluck(:email)).to match_array(DemoScenario::Installer::PUBLIC_ACCOUNTS.values)
    end
  end
end
