require "rails_helper"

RSpec.describe "Credenciais do cenário demo", type: :system do
  before do
    driven_by(:rack_test)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("true")
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_PASSWORD").and_return("senha-publica")
  end

  around do |example|
    timestamp = Time.zone.parse("2026-08-30 12:00:00")
    scenario = DemoScenario.find_by(key: DemoScenario::Installer::SCENARIO_KEY)
    created_scenario = scenario.nil?
    scenario ||= DemoScenario.create!(
      key: DemoScenario::Installer::SCENARIO_KEY,
      version: DemoScenario::Installer::SCENARIO_VERSION,
      installed_at: timestamp,
      last_reset_at: timestamp
    )

    example.run
  ensure
    DemoScenario.where(id: scenario&.id, key: DemoScenario::Installer::SCENARIO_KEY).delete_all if created_scenario
  end

  it "apresenta o aviso e as credenciais antes do formulário de entrada sem JavaScript" do
    visit new_user_session_path

    expect(page).to have_css("aside[aria-labelledby='demo-banner-title']")
    expect(page).to have_text("Ambiente compartilhado de demonstração")
    expect(page).to have_text("ana@demo.quitando.test")
    expect(page).to have_text("senha-publica")
    expect(page).to have_text("Próximo reset")
    expect(page).to have_css("#user_email[autofocus]")
    expect(page).not_to have_link("Esqueci minha senha")
  end
end
