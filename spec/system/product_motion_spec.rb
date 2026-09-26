require "rails_helper"

RSpec.describe "Movimento e estrutura do produto", type: :system do
  before { driven_by(:chrome_headless) }

  after do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  it "anima a entrada e revela uma seção ao rolar, mantendo o header visível" do
    page.current_window.resize_to(1440, 1000)
    visit root_path
    expect(page).to have_css(".landing-hero h1[data-revealed='true']")
    title = page.find(".landing-hero h1")
    expect(page.evaluate_script("getComputedStyle(arguments[0]).animationName", title)).to eq("product-reveal")
    section = page.find("#engenharia")
    page.execute_script("arguments[0].scrollIntoView()", section)
    expect(page).to have_css("#engenharia[data-revealed='true']")
    expect(page.evaluate_script("document.querySelector('.site-header').getBoundingClientRect().top")).to eq(0)
    expect(page.evaluate_script("getComputedStyle(arguments[0]).animationDuration", section)).to eq("0.6s")
    page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
    expect(page.evaluate_script("getComputedStyle(arguments[0]).animationName", section)).to eq("none")
    expect(page.evaluate_script("getComputedStyle(arguments[0]).opacity", section)).to eq("1")
  end

  it "respeita movimento reduzido inclusive quando a preferência muda durante a sessão" do
    visit root_path
    expect(page).to have_css(".landing-page.motion-enabled")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    expect(page).not_to have_css(".landing-page.motion-enabled")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.landing-hero h1')).opacity")).to eq("1")
    visit root_path
    expect(page).to have_css("#landing-title", text: "Divida os gastos.")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.landing-hero h1')).animationName")).to eq("none")
  end

  it "mostra a captura do Resumo no tema escolhido ou na preferência do sistema" do
    page.current_window.resize_to(1440, 1000)
    visit root_path

    within(".site-navigation--desktop") { select "Escuro", from: "Tema" }
    expect(page).to have_css(".landing-dashboard-screenshot__theme--dark", visible: true)
    expect(page).not_to have_css(".landing-dashboard-screenshot__theme--light", visible: true)

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: "light" } ])
    within(".site-navigation--desktop") { select "Claro", from: "Tema" }
    expect(page).to have_css(".landing-dashboard-screenshot__theme--light", visible: true)
    expect(page).not_to have_css(".landing-dashboard-screenshot__theme--dark", visible: true)

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: "dark" } ])
    within(".site-navigation--desktop") { select "Sistema", from: "Tema" }
    expect(page).to have_css(".landing-dashboard-screenshot__theme--dark", visible: true)
    expect(page).not_to have_css(".landing-dashboard-screenshot__theme--light", visible: true)
  end

  it "preserva navegação e largura nos dois temas e três viewports" do
    visit root_path
    %w[light dark].each do |theme|
      page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme)
      [ 360, 768, 1440 ].each do |width|
        page.current_window.resize_to(width, 1000)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
        expect(page.evaluate_script("document.querySelector('.site-header').getBoundingClientRect().height")).to be <= 80
        expect(page).to have_css("footer .wordmark img")
        if width < 1024
          page.find(".site-navigation__mobile summary").click
          within(".site-navigation__mobile-panel") { expect(page).to have_link("Conheça o app", href: "/#produto") }
          page.find(".site-navigation__mobile summary").click
        end
      end
    end
    page.current_window.resize_to(360, 844)
    page.find(".site-navigation__mobile summary").send_keys(:enter)
    expect(page).to have_css(".site-navigation__mobile[open]")
  end

  it "mantém conteúdo e menu operacionais sem JavaScript" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    visit root_path
    page.current_window.resize_to(360, 844)
    expect(page).to have_css("#landing-title", text: "Divida os gastos.")
    page.find(".site-navigation__mobile summary").click
    within(".site-navigation__mobile-panel") { click_link "Conheça o app" }
    expect(page).to have_css("#product-title", text: "Saiba o que fazer agora.")
    expect(page).to have_css("footer")
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  it "mantém a página estática quando o navegador não oferece IntersectionObserver" do
    script = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: "delete window.IntersectionObserver")
    visit root_path
    expect(page).to have_css("#landing-title", text: "Divida os gastos.")
    expect(page).not_to have_css(".motion-enabled")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('#landing-title')).opacity")).to eq("1")
    expect(page).to have_link("Criar conta")
  ensure
    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script.fetch("identifier")) if script
  end

  it "retorna à landing pelo histórico Turbo sem esconder conteúdo ou repetir a entrada" do
    page.current_window.resize_to(1440, 1000)
    visit root_path
    expect(page).to have_css("#landing-title[data-revealed='true']")
    within(".site-navigation--desktop") { click_link "Entrar" }
    expect(page).to have_css("#session-title")
    page.go_back
    expect(page).to have_css("#landing-title[data-revealed='true']")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('#landing-title')).opacity")).to eq("1")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('#landing-title')).animationName")).to eq("none")
  end
end
