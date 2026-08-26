require "rails_helper"

RSpec.describe "Histórico e configurações do grupo" do
  it "renderiza os destinos por HTTP e rejeita página malformada" do
    user = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")
    post user_session_path, params: { user: { email: user.email, password: user.password } }

    get group_history_path(group)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Histórico")

    get group_settings_path(group)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Configurações")

    get group_history_path(group, page: "zero")
    expect(response).to have_http_status(:unprocessable_content)
  end
end
