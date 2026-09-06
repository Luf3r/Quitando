require "rails_helper"

RSpec.describe "Páginas de autenticação" do
  it "apresenta entrada localizada" do
    get new_user_session_path

    expect(response.body).to include("Entrar no Quitando")
    expect(response.body).to include("E-mail")
    expect(response.body).to include("Senha")
    expect(response.body).to include("Esqueci minha senha")
  end

  it "apresenta cadastro localizado" do
    get new_user_registration_path

    expect(response.body).to include("Criar sua conta")
    expect(response.body).to include("Confirme a senha")
    document = Nokogiri::HTML(response.body)
    name_input = document.at_css("#user_name")
    email_input = document.at_css("#user_email")
    expect(name_input).to be_present
    expect(name_input["required"]).to eq("required")
    expect(name_input["maxlength"]).to eq("80")
    expect(name_input.path).to be < email_input.path
    expect(response.body).not_to match(/cancel my account|excluir conta/i)
  end

  it "cadastra nome normalizado pelo parâmetro permitido do Devise" do
    post user_registration_path, params: {
      user: {
        name: "  Ana   Vitória  ",
        email: "ana.vitoria@example.com",
        password: "senha-segura",
        password_confirmation: "senha-segura"
      }
    }

    expect(response).to redirect_to(root_path)
    expect(User.find_by!(email: "ana.vitoria@example.com").name).to eq("Ana Vitória")
  end

  it "apresenta recuperação de senha localizada" do
    get new_user_password_path

    expect(response.body).to include("Recuperar senha")
    expect(response.body).to include("Enviar instruções")
  end

  it "não emite recuperação para conta demo e responde como para e-mail desconhecido" do
    demo_user = create(:user, :demo_account, email: "ana-demo-#{SecureRandom.hex(4)}@example.com")

    post user_password_path, params: { user: { email: demo_user.email } }

    demo_response = [ response.status, response.location, flash[:notice] ]
    expect(demo_user.reload.reset_password_token).to be_nil

    post user_password_path, params: { user: { email: "ausente@example.com" } }

    expect([ response.status, response.location, flash[:notice] ]).to eq(demo_response)
  end

  it "não emite recuperação quando o e-mail demo usa maiúsculas ou espaços do Devise" do
    demo_user = create(:user, :demo_account, email: "ana-demo-#{SecureRandom.hex(4)}@example.com")

    post user_password_path, params: { user: { email: "ausente@example.com" } }
    unknown_response = [ response.status, response.location, flash[:notice] ]
    unknown_error_markup = password_error_markup(response.body)

    expect(unknown_error_markup).to be_present

    [ demo_user.email.upcase, "  #{demo_user.email.upcase}  " ].each do |email|
      post user_password_path, params: { user: { email: } }

      expect([ response.status, response.location, flash[:notice] ]).to eq(unknown_response)
      expect(password_error_markup(response.body)).to eq(unknown_error_markup)
      expect(demo_user.reload.reset_password_token).to be_nil
    end
  end

  it "não permite que um token de recuperação existente altere a senha demo" do
    demo_user = create(:user, :demo_account, email: "ana-demo-#{SecureRandom.hex(4)}@example.com", password: "senha-publica")
    token = demo_user.send_reset_password_instructions

    put user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "nova-senha",
        password_confirmation: "nova-senha"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(demo_user.reload.valid_password?("senha-publica")).to be(true)
    expect(demo_user.valid_password?("nova-senha")).to be(false)
  end

  it "mostra credenciais e política demo no login sem oferecer recuperação" do
    enable_demo_mode!
    create_demo_scenario!

    get new_user_session_path

    expect(response.body).to include("Ambiente compartilhado de demonstração")
    expect(response.body).to include("ana@demo.quitando.test")
    expect(response.body).to include("senha-publica")
    expect(response.body).to include("Próximo reset")
    expect(response.body).not_to include("Esqueci minha senha")
  end

  private

  def enable_demo_mode!
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_PASSWORD").and_return("senha-publica")
  end

  def create_demo_scenario!
    timestamp = Time.zone.parse("2026-08-30 12:00:00")
    DemoScenario.find_or_create_by!(key: DemoScenario::Installer::SCENARIO_KEY) do |scenario|
      scenario.version = DemoScenario::Installer::SCENARIO_VERSION
      scenario.installed_at = timestamp
      scenario.last_reset_at = timestamp
    end
  end

  def password_error_markup(body)
    Nokogiri::HTML(body).at_css("form.auth-form .ui-alert")&.to_html
  end
end
