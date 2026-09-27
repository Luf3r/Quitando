require "rails_helper"

RSpec.describe "Ambientes locais por host" do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_LOCAL_DUAL_DATABASE").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_URL").and_return("http://demo.localhost:3000")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return(nil)
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_PASSWORD").and_return("senha-publica")

    ApplicationRecord.connected_to(role: :writing, shard: :demo) do
      DemoScenario.find_or_create_by!(key: DemoScenario::Installer::SCENARIO_KEY) do |scenario|
        scenario.version = DemoScenario::Installer::SCENARIO_VERSION
        scenario.installed_at = Time.current
        scenario.last_reset_at = Time.current
      end
    end
  end

  it "mostra caminhos para conta real e demo no host principal e o aviso apenas na demo" do
    host! "localhost"
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Entrar", "Criar conta", "Entrar na demonstração")
    expect(response.body).not_to include("Somente este ambiente é compartilhado")

    host! "demo.localhost"
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Espaço de teste compartilhado", "Criar conta durável")
  end

  it "impede cadastro na demo e mantém o cadastro real disponível" do
    host! "demo.localhost"
    post user_registration_path, params: { user: { name: "Pessoa Demo", email: "nova@example.com", password: "senha-segura", password_confirmation: "senha-segura" } }
    expect(response).to have_http_status(:forbidden)
    ApplicationRecord.connected_to(role: :writing, shard: :demo) do
      expect(User.exists?(email: "nova@example.com")).to be(false)
    end

    host! "localhost"
    post user_registration_path, params: { user: { name: "Pessoa Real", email: "nova@example.com", password: "senha-segura", password_confirmation: "senha-segura" } }
    expect(response).to redirect_to(root_path)
    expect(User.exists?(email: "nova@example.com")).to be(true)
  end

  it "não autentica usuários de um banco no outro nem compartilha sessão entre hosts" do
    create(:user, email: "mesmo@example.com", name: "Pessoa Real", password: "senha-real")
    ApplicationRecord.connected_to(role: :writing, shard: :demo) do
      create(:user, email: "mesmo@example.com", name: "Pessoa Demo", password: "senha-demo", demo_account: true)
    end

    host! "localhost"
    post user_session_path, params: { user: { email: "mesmo@example.com", password: "senha-real" } }
    expect(response).to redirect_to(root_path)
    get groups_path
    expect(response).to have_http_status(:ok)

    host! "demo.localhost"
    get groups_path
    expect(response).to redirect_to(new_user_session_path)
    post user_session_path, params: { user: { email: "mesmo@example.com", password: "senha-real" } }
    expect(response).not_to redirect_to(groups_path)
    post user_session_path, params: { user: { email: "mesmo@example.com", password: "senha-demo" } }
    expect(response).to redirect_to(groups_path)
    get groups_path
    expect(response).to have_http_status(:ok)

    host! "localhost"
    get groups_path
    expect(response).to have_http_status(:ok)
  end
  it "recusa host desconhecido antes de acessar dados" do
    host! "desconhecido.localhost"
    expect(User).not_to receive(:find_by)
    get root_path
    expect(response).to have_http_status(:bad_request)
  end

  it "aceita o host de loopback usado pelo navegador dos system specs como ambiente real" do
    host! "127.0.0.1"

    get root_path

    expect(response).to have_http_status(:ok)
  end
end
