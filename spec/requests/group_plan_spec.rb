require "rails_helper"

RSpec.describe "Plano do grupo" do
  it "expõe por HTTP a página do plano com navegação e pendências" do
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    group = GroupCreator.call(owner_user_id: ana.id, name: "Viagem")
    create(:membership, group:, user: bruno, position: 1)

    post user_session_path, params: { user: { email: ana.email, password: ana.password } }
    get group_plan_path(group)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Plano líquido")
    expect(response.body).to include("Resumo")
    expect(response.body).to include("Histórico")
    expect(response.body).to include("Configurações")
    expect(response.body).to include("Nenhum pagamento aguarda confirmação.")
  end
end
