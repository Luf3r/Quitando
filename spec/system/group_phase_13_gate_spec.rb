require "rails_helper"

RSpec.describe "Gate responsivo da Fase 13", type: :system do
  after do
    if page.driver.class.name.include?("Selenium")
      page.execute_script("localStorage.removeItem('quitando.theme')")
      page.current_window.resize_to(1400, 1400)
    end
    Capybara.reset_sessions!
  end

  context "com navegador e JavaScript" do
    before { driven_by(:chrome_headless) }

    it "mantém as cinco telas financeiras legíveis nos temas e viewports normativos" do
      fixture = create_fixture!
      sign_in(fixture.fetch(:member))

      paths = [
        group_path(fixture.fetch(:group)),
        group_history_path(fixture.fetch(:group)),
        group_settings_path(fixture.fetch(:group)),
        group_payment_path(fixture.fetch(:group), fixture.fetch(:reported_payment)),
        group_expense_path(fixture.fetch(:group), fixture.fetch(:expense))
      ]

      { "Claro" => "light", "Escuro" => "dark" }.each do |theme_name, theme_value|
        page.current_window.resize_to(1440, 1000)
        visit group_path(fixture.fetch(:group))
        select theme_name, from: "Tema"

        [ [ 360, 844 ], [ 768, 1024 ], [ 1440, 1000 ] ].each do |width, height|
          page.current_window.resize_to(width, height)

          paths.each do |path|
            visit path

            expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq(theme_value)
            expect(viewport_has_no_horizontal_overflow?).to be(true), "overflow em #{path} com #{width}px no tema #{theme_value}"
          end

          visit group_path(fixture.fetch(:group))
          within("#group_dashboard_financial_summary") do
            expect(page).to have_css("dt", text: "Saldo oficial")
            expect(page).to have_css("dd", text: "-R$ 2,00")
          end
          expect(page.find("#group_next_action")).to have_link("Acompanhar pagamento")

          if width == 360
            expect_mobile_action_bar_to_fit_safely if page.has_css?("#group_mobile_actions")
          else
            expect(page).not_to have_css("#group_mobile_actions", visible: :visible)
          end
        end
      end

      visit group_history_path(fixture.fetch(:group))
      statuses = page.all("[data-status]", minimum: 0).map { |node| node["data-status"] }
      expect(page).to have_link("Próxima")
      visit group_history_path(fixture.fetch(:group), page: 2)
      statuses.concat(page.all("[data-status]", minimum: 0).map { |node| node["data-status"] })
      expect(statuses).to include("active", "voided", "reported", "confirmed", "cancelled")

      visit group_payment_path(fixture.fetch(:group), fixture.fetch(:reported_payment))
      cancellation = page.find("details.payment-cancellation")
      expect(page.evaluate_script("arguments[0].open", cancellation)).to be(false)
      expect(page).to have_field("Motivo do cancelamento", visible: :hidden)
      cancellation.find("summary", text: "Cancelar pagamento").click
      expect(page).to have_field("Motivo do cancelamento", visible: :visible)

      visit group_path(fixture.fetch(:group))
      page.find("body").send_keys(:tab)
      focus = page.evaluate_script(<<~JS)
        (() => {
          const element = document.activeElement
          const style = getComputedStyle(element)
          return { tag: element.tagName, outlineStyle: style.outlineStyle, outlineWidth: style.outlineWidth }
        })()
      JS
      expect(focus.fetch("tag")).not_to eq("BODY")
      expect(focus.fetch("outlineStyle")).not_to eq("none")
      expect(focus.fetch("outlineWidth")).not_to eq("0px")

      page.execute_script(<<~JS)
        document.body.insertAdjacentHTML(
          "beforeend",
          '<div id="phase_13_overflow_control" style="width: 200vw; height: 1px"></div>'
        )
      JS
      expect(viewport_has_no_horizontal_overflow?).to be(false)
      page.execute_script("document.getElementById('phase_13_overflow_control').remove()")
      expect(viewport_has_no_horizontal_overflow?).to be(true)
    end
  end

  context "sem JavaScript" do
    before { driven_by(:rack_test) }

    it "mantém detalhes e formulários financeiros operacionais por HTTP" do
      fixture = create_fixture!
      sign_in(fixture.fetch(:member))

      visit group_payment_path(fixture.fetch(:group), fixture.fetch(:reported_payment))
      cancellation = Nokogiri::HTML(page.html).at_css("details.payment-cancellation")
      expect(cancellation).not_to have_attribute("open")
      expect(cancellation.at_css("input[name='payment[reason]'][required]")).to be_present
      page.find("input[name='payment[reason]']", visible: :all).set("Transferência não realizada")
      page.find("input.ui-button--danger", visible: :all).click
      expect(page).to have_css("[data-status='cancelled']", text: "Cancelado")

      visit group_expense_path(fixture.fetch(:group), fixture.fetch(:expense))
      fill_in "Descrição", with: "Compra semanal revisada"
      click_button "Salvar descrição"
      expect(page).to have_css("h1", text: "Compra semanal revisada")
    end
  end

  private

  def expect_mobile_action_bar_to_fit_safely
    action_bar = page.find("#group_mobile_actions")
    page.execute_script("arguments[0].scrollIntoView({ block: 'end' })", action_bar)

    geometry = page.evaluate_script(<<~JS, action_bar)
      (() => {
        const rect = arguments[0].getBoundingClientRect()
        return {
          top: rect.top,
          bottom: rect.bottom,
          right: rect.right,
          viewportHeight: window.innerHeight,
          viewportWidth: document.documentElement.clientWidth,
          actionCount: arguments[0].querySelectorAll("a, button").length
        }
      })()
    JS
    expect(geometry.fetch("actionCount")).to be <= 2
    expect(geometry.fetch("top")).to be >= 0
    expect(geometry.fetch("bottom")).to be <= geometry.fetch("viewportHeight")
    expect(geometry.fetch("right")).to be <= geometry.fetch("viewportWidth")
  end

  def viewport_has_no_horizontal_overflow?
    page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  def create_fixture!
    owner = create(:user, name: "Ana responsável pela casa compartilhada", email: "ana-fase-13-gate@example.com")
    member = create(:user, name: "Bruno com um nome deliberadamente longo para testar quebras seguras", email: "bruno-fase-13-gate@example.com")
    invited = create(:user, email: "convidada-fase-13-gate@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento Fase 13 com um nome longo para testar superfícies estreitas")
    create(:membership, group:, user: member, position: 1)
    create(:group_invitation, group:, invited_user: invited, invited_by_user: owner, expires_at: 2.days.from_now)
    expense = ExpenseCreator.call(
      group_id: group.id,
      created_by_user_id: member.id,
      paid_by_user_id: owner.id,
      description: "Compra semanal com uma descrição extensa que precisa quebrar sem ampliar a página",
      occurred_on: Date.new(2026, 8, 14),
      amount_text: "6,00",
      split: { type: :equal, participant_user_ids: [ owner.id, member.id ] }
    )

    22.times do |index|
      create(:expense, :voided, group:, paid_by_user: owner, created_by_user: member, voided_by_user: member, description: "Despesa anulada #{index + 1}")
    end

    reported_payment = create(:payment, group:, from_user: member, to_user: owner, reported_by_user: member, status: :reported, amount_cents: 100)
    create(:payment, :confirmed, group:, from_user: member, to_user: owner, reported_by_user: member, amount_cents: 100)
    create(:payment, :cancelled, group:, from_user: member, to_user: owner, reported_by_user: member, amount_cents: 100)

    { group:, owner:, member:, expense:, reported_payment: }
  end

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button "Entrar"
    expect(page).to have_current_path(root_path)
  end
end
