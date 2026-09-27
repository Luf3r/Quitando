require "rails_helper"

RSpec.describe "Cenário da captura pública", type: :system do
  before { driven_by(:chrome_headless) }

  it "mostra uma situação real de Ana com envio para revisar e próximos passos" do
    ana, bruno, carla = %w[Ana Bruno Carla].map do |name|
      create(:user, name:, password: "senha-segura", password_confirmation: "senha-segura")
    end
    group = GroupCreator.call(owner_user_id: ana.id, name: "Casa da Vila")
    create(:membership, group:, user: bruno, position: 1)
    create(:membership, group:, user: carla, position: 2)
    [ [ ana, "Compras da semana", "240,00" ], [ bruno, "Jantar de domingo", "90,00" ] ].each do |payer, description, amount_text|
      ExpenseCreator.call(group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
                          description:, occurred_on: Date.new(2026, 9, 20), amount_text:,
                          split: { type: :equal, participant_user_ids: [ ana.id, bruno.id, carla.id ] })
    end
    PaymentReporter.call(group_id: group.id, actor_user_id: carla.id, from_user_id: carla.id, to_user_id: ana.id,
                         amount_text: "60,00", expected_financial_state_version: group.reload.financial_state_version,
                         idempotency_key: SecureRandom.uuid)

    visit new_user_session_path
    fill_in "E-mail", with: ana.email
    fill_in "Senha", with: "senha-segura"
    within("form.auth-form") { click_button "Entrar" }
    expect(page).to have_current_path(root_path)
    visit group_path(group)
    page.current_window.resize_to(1440, 1400)
    within(".site-navigation--desktop") { select "Claro", from: "Tema" }
    expect(page).to have_css("h1", text: "Casa da Vila")
    expect(page).to have_link("Revisar pagamento")
    within("#group_dashboard_financial_summary") do
      expect(page).to have_text("Carla marcou como enviado")
      expect(page).to have_text("R$ 130,00")
      expect(page).to have_text("R$ 70,00")
      expect(page).to have_text("Participantes")
    end
    next unless ENV["CAPTURE_LANDING"] == "true"

    FileUtils.mkdir_p(Rails.root.join("tmp/polish"))
    page.driver.browser.execute_async_script("document.fonts.ready.then(() => arguments[0]())")
    page.find("h1").click
    page.save_screenshot(Rails.root.join("tmp/polish/dashboard-light-desktop.png"))
    page.current_window.resize_to(480, 1550)
    page.save_screenshot(Rails.root.join("tmp/polish/dashboard-light-mobile.png"))
    page.current_window.resize_to(1440, 1400)
    within(".site-navigation--desktop") { select "Escuro", from: "Tema" }
    sleep 0.25
    page.execute_script("document.activeElement.blur(); window.scrollTo(0, 0); document.documentElement.style.overflow = 'hidden'; document.body.style.overflow = 'hidden'; const captureStyle = document.createElement('style'); captureStyle.textContent = '::-webkit-scrollbar { display: none !important; }'; document.head.append(captureStyle)")
    page.save_screenshot(Rails.root.join("tmp/polish/dashboard-dark-desktop.png"))
    page.current_window.resize_to(480, 1550)
    page.save_screenshot(Rails.root.join("tmp/polish/dashboard-dark-mobile.png"))
  end
end
