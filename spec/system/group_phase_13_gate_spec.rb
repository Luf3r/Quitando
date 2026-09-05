require "rails_helper"

RSpec.describe "Gate responsivo da Fase 13", type: :system do
  before { driven_by(:chrome_headless) }

  after do
    page.execute_script("localStorage.removeItem('quitando.theme')")
    page.current_window.resize_to(1400, 1400)
    Capybara.reset_sessions!
  end

  it "mantém saldo e próxima ação acessíveis sem estouro horizontal em todos os viewports normativos" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))

    {
      "Claro" => "light",
      "Escuro" => "dark"
    }.each do |theme_name, theme_value|
      select theme_name, from: "Tema"

      [ [ 360, 844 ], [ 768, 1024 ], [ 1440, 1000 ] ].each do |width, height|
        page.current_window.resize_to(width, height)
        visit group_path(fixture.fetch(:group))

        expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq(theme_value)
        expect(page.find("#group_dashboard_financial_summary")).to have_text("Saldo oficial: -R$ 3,00")
        expect(page.find("#group_next_action")).to have_text("Próxima ação")
        expect(page.find("#group_next_action")).to have_link("Marcar como enviado")
        expect(viewport_has_no_horizontal_overflow?).to be(true)

        if width == 360
          expect_mobile_action_bar_to_fit_safely
        else
          expect(page).to have_css("#group_mobile_actions", visible: :hidden)
        end
      end
    end

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
    owner = create(:user, email: "ana-fase-13-gate@example.com")
    member = create(:user, email: "bruno-fase-13-gate@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento Fase 13")
    create(:membership, group:, user: member, position: 1)
    expense = create(:expense, group:, paid_by_user: owner, created_by_user: owner, amount_cents: 300)
    create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)

    { group:, member: }
  end

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button "Entrar"
    expect(page).to have_current_path(root_path)
  end
end
