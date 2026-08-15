require "rails_helper"

RSpec.describe "CSRF" do
  it "rejeita mutação HTML sem token quando a proteção está habilitada" do
    user = create(:user, email: "ana@example.com")
    post user_session_path, params: { user: { email: user.email, password: user.password } }

    previous_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post groups_path, params: { group: { name: "Apartamento" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Group.where(name: "Apartamento")).to be_empty
  ensure
    ActionController::Base.allow_forgery_protection = previous_setting
  end
end
