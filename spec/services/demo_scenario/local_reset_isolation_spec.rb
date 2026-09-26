require "rails_helper"

RSpec.describe "Reset local isolado" do
  it "recria apenas o banco demo e preserva os usuários reais" do
    real_user = create(:user, email: "duravel@example.com")
    environment = {
      "QUITANDO_DEMO_MODE" => "false",
      "QUITANDO_LOCAL_DUAL_DATABASE" => "true",
      "QUITANDO_DEMO_DATABASE_NAME" => "quitando_demo_test",
      "QUITANDO_DEMO_PASSWORD" => "senha-publica",
      "CONFIRM_DEMO_RESET" => "quitando-demo-only"
    }

    ApplicationRecord.connected_to(role: :writing, shard: :demo) do
      create(:user, email: "descartavel@example.com")
      DemoScenario::Resetter.call(config: DemoScenario::Config.new(environment:), manual: true)
      expect(User.exists?(email: "descartavel@example.com")).to be(false)
      expect(User.where(demo_account: true).count).to eq(4)
    end

    expect(User.find(real_user.id)).to eq(real_user)
    expect(User.where(demo_account: true)).to be_empty
  end
end
