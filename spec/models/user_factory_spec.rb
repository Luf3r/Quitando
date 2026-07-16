require "rails_helper"

RSpec.describe "user factory" do
  it "cria um usuário válido" do
    user = create(:user)

    expect(user).to be_persisted
    expect(user.email).to match(/\Auser\d+@example\.com\z/)
  end
end
