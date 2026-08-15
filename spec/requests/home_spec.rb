require "rails_helper"

RSpec.describe "Home" do
  it "liga o usuário autenticado às jornadas de grupos e convites" do
    user = create(:user, email: "ana@example.com")

    post user_session_path, params: { user: { email: user.email, password: user.password } }
    get root_path

    expect(response.body).to include('href="/groups"')
    expect(response.body).to include('href="/invitations"')
  end
end
