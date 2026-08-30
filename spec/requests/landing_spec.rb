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
    expect(response.body).to include("Feche as contas do grupo sem refazer cada dívida.")
    expect(response.body).to include("Registre despesas, acompanhe confirmações e veja um plano prático com menos transferências.")
    expect(document.css("a").map(&:text)).to include("Criar conta")
    expect(document.at_css("a[href='#como-funciona']")&.text).to eq("Como funciona")
    expect(document.at_css("meta[property='og:image']")["content"]).to match(/hero-friends-og(?:-[a-f0-9]+)?\.webp/)
    expect(document.at_css(".landing-hero picture img")["alt"]).to include("Quatro amigos")
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

  it "publica metadata, canonical e Open Graph coerentes" do
    get root_url

    document = Nokogiri::HTML(response.body)

    expect(document.at_css("html")["lang"]).to eq("pt-BR")
    expect(document.at_css("title").text).to include("Quitando")
    expect(document.at_css("meta[name='description']")["content"]).to include("plano prático")
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
