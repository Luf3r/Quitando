require "rails_helper"

RSpec.describe "Landing pública" do
  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
  end

  it "apresenta a proposta, CTAs e seções na ordem definida para visitante" do
    get root_path

    document = Nokogiri::HTML(response.body)
    section_ids = document.css("main section[id]").map { |section| section["id"] }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Divida os gastos.")
    expect(response.body).to include("Organize as despesas com amigos e veja o que falta para todo mundo ficar em dia.")
    expect(document.css("a").map(&:text)).to include("Criar conta")
    expect(document.at_css("a[href='#como-funciona']")&.text).to eq("Como funciona")
    expect(document.at_css("meta[property='og:image']")["content"]).to match(/hero-friends-og(?:-[a-f0-9]+)?\.webp/)
    expect(document.at_css(".landing-hero picture img")["alt"]).to include("amigos", "celular")
    expect(section_ids).to eq(%w[como-funciona estados produto engenharia confianca comecar])
    expect(document.at_css(".landing-product img")&.[]("src")).to match(/dashboard-summary(?:-[a-f0-9]+)?\.webp/)
    expect(document.css(".landing-dashboard-preview")).to be_empty
    expect(document.css(".eyebrow").count).to be <= 3
    expect(response.body).not_to match(/preços|depoimentos|clientes atendidos/i)
  end

  it "troca o CTA principal por Abrir app para uma pessoa autenticada" do
    user = create(:user)
    sign_in_as user

    get root_path

    document = Nokogiri::HTML(response.body)
    expect(document.css("a[href='/groups']").map(&:text)).to include("Abrir app")
    expect(document.css(".landing-hero a").map(&:text)).not_to include("Criar conta")
  end

  it "mostra os acessos públicos de teste no ambiente de demonstração" do
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

    expect(access_section&.text).to include(*DemoScenario::Installer::PUBLIC_ACCOUNTS.values, "senha-publica", "seis horas")
    expect(access_section&.css("a").map(&:text)).to include("Entrar com conta de teste")
    expect(document.at_css("aside.demo-banner")&.text).to include("acessos de teste")
    expect(document.at_css("aside.demo-banner")&.text).not_to include("Senha:", *DemoScenario::Installer::PUBLIC_ACCOUNTS.values)
    expect(document.css("main section[id]").map { |section| section["id"] }).to include("acessos-teste")
  end

  it "não mostra credenciais demo quando o ambiente compartilhado está desligado" do
    get root_path

    expect(response.body).not_to include("acessos-teste", *DemoScenario::Installer::PUBLIC_ACCOUNTS.values)
  end

  it "publica metadata, canonical e Open Graph coerentes" do
    get root_url

    document = Nokogiri::HTML(response.body)

    expect(document.at_css("html")["lang"]).to eq("pt-BR")
    expect(document.at_css("title").text).to include("Quitando")
    expect(document.at_css("meta[name='description']")["content"]).to include("despesas com amigos")
    expect(document.at_css("link[rel='canonical']")["href"]).to eq(root_url)
    expect(document.at_css("meta[property='og:title']")["content"]).to be_present
    expect(document.at_css("meta[property='og:description']")["content"]).to be_present
    expect(document.at_css("meta[property='og:type']")["content"]).to eq("website")
  end

  it "não expõe o banner ou credenciais demo fora do modo demo" do
    get root_path

    expect(response.body).not_to include("Ambiente compartilhado de demonstração")
    expect(response.body).not_to include("senha-publica")
  end
end
