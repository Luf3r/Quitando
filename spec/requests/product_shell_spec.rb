require "rails_helper"

RSpec.describe "Identidade e linguagem do produto" do
  it "oferece marca, navegação pública e footer com destinos reais" do
    get root_path
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("header .wordmark img")&.[]("src")).to eq("/quitando-logo.png")
    expect(document.at_css("header .wordmark")&.text).to be_blank
    expect(document.at_css("header .wordmark")&.[]("aria-label")).to eq("Quitando, página inicial")
    expect(document.css("link[rel='icon']").map { |link| link["sizes"] }).to include("16x16", "32x32", "48x48")
    expect(document.at_css("link[rel='apple-touch-icon']")&.[]("href")).to eq("/apple-touch-icon.png")
    %w[/favicon-16x16.png /favicon-32x32.png /favicon-48x48.png /apple-touch-icon.png].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
    end
    get root_path
    document = Nokogiri::HTML(response.body)
    %w[header footer].each do |selector|
      links = document.css("#{selector} a").map { |link| [ link.text.strip, link["href"] ] }
      expect(links).to include([ "Como funciona", "/#como-funciona" ], [ "Conheça o app", "/#produto" ])
      expect(links).to include([ "Entrar", new_user_session_path ], [ "Criar conta", new_user_registration_path ])
    end
    expect(document.at_css("footer")&.text).to include("Divida os gastos. Aproveite a companhia.")
    expect(document.at_css("footer .wordmark")&.text).to be_blank
    expect(document.at_css("footer .wordmark")&.[]("aria-label")).to eq("Quitando, página inicial")
    expect(document.at_css("h1")&.text).to eq("Divida os gastos. Acerte as contas.")
    expect(document.at_css("#como-funciona")&.text).to include("fora do app", "quem recebeu confirma")
    expect(document.at_css("main")&.text).not_to match(/HTTP|MVP|bilateral|derivada|reportado/)
  end

  it "mantém os destinos autenticados e usa footer compacto dentro do app" do
    user = create(:user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    get groups_path
    document = Nokogiri::HTML(response.body)
    expect(document.css("header a").map { |link| link["href"] }).to include(groups_path, invitations_path, account_path)
    expect(document.at_css("footer.site-footer--compact")).to be_present
    expect(document.css("footer a").map { |link| link["href"] }).to include(root_path, account_path)
    expect(document.css("footer a").map(&:text)).not_to include("Criar conta")
  end

  it "mantém o aviso e os acessos de teste claros na landing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_PASSWORD").and_return("senha-publica")
    DemoScenario.find_or_create_by!(key: DemoScenario::Installer::SCENARIO_KEY) do |scenario|
      scenario.version = DemoScenario::Installer::SCENARIO_VERSION
      scenario.installed_at = Time.current
      scenario.last_reset_at = Time.current
    end
    get root_path
    document = Nokogiri::HTML(response.body)
    access_section = document.at_css("section#acessos-teste")
    expect(document.at_css("aside.demo-banner")&.text).to include("Somente este ambiente", "compartilhado", "apagados", "acessos de teste")
    expect(document.at_css("aside.demo-banner")&.text).not_to include("Senha:", *DemoScenario::Installer::PUBLIC_ACCOUNTS.values)
    expect(access_section&.text).to include(*DemoScenario::Installer::PUBLIC_ACCOUNTS.values, "Senha de teste", "Próxima atualização dos exemplos", "compartilhado")
    expect(document.at_css("aside.demo-banner")&.text).not_to include("demo-only")
  end

  it "apresenta os logins de teste no site real e aponta para a demo" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("false")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_URL").and_return("https://demo.quitando.example")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_PASSWORD").and_return("senha-publica")

    get root_path

    document = Nokogiri::HTML(response.body)
    access_section = document.at_css("section#acessos-teste")
    expect(access_section&.text).to include(*DemoScenario::Installer::PUBLIC_ACCOUNTS.values, "senha-publica")
    expect(access_section.at_css("a[href='https://demo.quitando.example/users/sign_in']")&.text).to include("Entrar na demonstração")
    expect(document.at_css("aside.demo-banner")).to be_nil
    expect(access_section.text).not_to include("Próximo reset")
  end

  it "não permite criar contas no ambiente demo" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_MAIN_URL").and_return("https://quitando.example")
    DemoScenario.find_or_create_by!(key: DemoScenario::Installer::SCENARIO_KEY) do |scenario|
      scenario.version = DemoScenario::Installer::SCENARIO_VERSION
      scenario.installed_at = Time.current
      scenario.last_reset_at = Time.current
    end

    get new_user_registration_path

    expect(response).to redirect_to("https://quitando.example/users/sign_up")
    expect do
      post user_registration_path, params: { user: { name: "Pessoa", email: "pessoa@example.com", password: "senha-segura", password_confirmation: "senha-segura" } }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:forbidden)
  end
end
