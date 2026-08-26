require "rails_helper"

RSpec.describe "Atualizações em tempo real do grupo", type: :system do
  self.use_transactional_tests = false
  PASSWORD = "realtime-password-segura".freeze

  before { driven_by(:chrome_headless) }

  after do
    Capybara.reset_sessions!
    ActionCable.server.restart
    cleanup_fixture!
  end

  it "entrega a despesa de terceiro, o report e a confirmação a outro navegador" do
    fixture = create_fixture!

    sign_in_in(:ana, fixture.fetch(:ana))
    visit_group_in(:ana, fixture.fetch(:group))
    in_session(:ana) { expect(page).to have_connected_group_stream }

    sign_in_in(:counterparty, fixture.fetch(:carla))
    visit_group_in(:counterparty, fixture.fetch(:group))
    in_session(:counterparty) { expect(page).to have_connected_group_stream }

    cable_channel = fixture.fetch(:group).id
    messages = SolidCable::Message.where(channel: cable_channel)
    messages_before_broadcast = messages.count
    transport_token = SecureRandom.hex(12)
    ActionCable.server.broadcast(
      cable_channel,
      "<turbo-stream action=\"append\" target=\"group_remote_notice\"><template><p>Prova de transporte Cable #{transport_token}</p></template></turbo-stream>"
    )
    expect(messages.count).to eq(messages_before_broadcast + 1)
    expect(messages.order(:id).last.payload).to include(transport_token)
    in_session(:ana) { expect(page).to have_text("Prova de transporte Cable") }

    Capybara.using_session(:counterparty) do
      click_link "Adicionar despesa"
      fill_equal_expense!(fixture, description: "Mercado registrado por Carla")
    end

    in_session(:ana) do
      expect(page).to have_text("pago por #{fixture.fetch(:bruno).email}, registrado por #{fixture.fetch(:carla).email}")
      expect(page).to have_css("#visualization_table_plan", text: fixture.fetch(:ana).email)
      expect(page).to have_css("svg[data-layer='plan']")
      expect(page).to have_css(
        "svg path[data-from-user-id='#{fixture.fetch(:ana).id}'][data-to-user-id='#{fixture.fetch(:bruno).id}']"
      )
    end

    Capybara.using_session(:ana) do
      click_link "Marcar como enviado"
      within("#group_dialog") { click_button "Marcar como enviado" }
    end

    in_session(:counterparty) do
      expect(page).to have_text("1 pagamento(s) reportado(s)")
      expect(page).to have_css("svg[data-layer='bilateral']")
    end

    sign_in_in(:bruno, fixture.fetch(:bruno))
    visit_group_in(:bruno, fixture.fetch(:group))
    Capybara.using_session(:bruno) do
      click_link "Pagamento reported"
      click_button "Confirmar pagamento"
    end

    in_session(:ana) do
      expect(page).to have_text("Quitado")
      expect(page).to have_text("0 pagamento(s) reportado(s)")
      expect(page).to have_text("pago por #{fixture.fetch(:bruno).email}, registrado por #{fixture.fetch(:carla).email}")
    end

    streamed_snapshot = within_in(:ana, "#group_dashboard_financial_summary") { page.text }
    reloaded_snapshot = in_session(:ana) do
      visit group_path(fixture.fetch(:group))
      find("#group_dashboard_financial_summary").text
    end

    expect(reloaded_snapshot).to eq(streamed_snapshot)
  end

  it "sinaliza uma desconexão Cable, não recebe a mudança e converge por reload HTTP" do
    fixture = create_fixture!

    sign_in_in(:ana, fixture.fetch(:ana))
    visit_group_in(:ana, fixture.fetch(:group))
    in_session(:ana) { expect(page).to have_connected_group_stream }

    ActionCable.server.remote_connections.where(current_user: fixture.fetch(:ana)).disconnect(reconnect: false)
    in_session(:ana) { expect(page).to have_text("Atualizações em tempo real indisponíveis.") }

    sign_in_in(:counterparty, fixture.fetch(:carla))
    visit_group_in(:counterparty, fixture.fetch(:group))
    Capybara.using_session(:counterparty) do
      click_link "Adicionar despesa"
      fill_equal_expense!(fixture, description: "Mudança fora da conexão")
    end

    Capybara.using_session(:ana) do
      expect(page).not_to have_text("Mudança fora da conexão", wait: 1)
      visit group_path(fixture.fetch(:group))
      expect(page).to have_text("Mudança fora da conexão")
    end
  end

  private

  def create_fixture!
    suffix = SecureRandom.hex(6)
    ana = create(:user, email: "ana-realtime-#{suffix}@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    bruno = create(:user, email: "bruno-realtime-#{suffix}@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    carla = create(:user, email: "carla-realtime-#{suffix}@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    group = create(:group, name: "Realtime #{suffix}")

    create(:membership, group:, user: ana, role: :owner, position: 0)
    create(:membership, group:, user: bruno, position: 1)
    create(:membership, group:, user: carla, position: 2)

    @fixture = { group:, ana:, bruno:, carla: }
  end

  def cleanup_fixture!
    return unless @fixture

    group = @fixture.fetch(:group)
    payments = Payment.where(group:)
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(payment_id: payments.select(:id)))
    payments.delete_all
    expenses = Expense.where(group_id: group.id)
    delete_expense_description_revisions_for_cleanup!(ExpenseDescriptionRevision.where(expense_id: expenses.select(:id)))
    delete_expense_history_for_cleanup!(expenses)
    Membership.where(group:).delete_all
    Group.where(id: group.id).delete_all
    User.where(id: @fixture.values_at(:ana, :bruno, :carla).map(&:id)).delete_all
  ensure
    @fixture = nil
  end

  def sign_in_in(session_name, user)
    Capybara.using_session(session_name) do
      visit new_user_session_path
      fill_in "user_email", with: user.email
      fill_in "user_password", with: PASSWORD
      find('input[type="submit"]').click
      expect(page).to have_current_path(root_path)
    end
  end

  def visit_group_in(session_name, group)
    Capybara.using_session(session_name) { visit group_path(group) }
  end

  def in_session(session_name, &)
    Capybara.using_session(session_name, &)
  end

  def fill_equal_expense!(fixture, description:)
    equal_form = find("#group_dialog input[name='expense[split_type]'][value='equal']", visible: :all).ancestor("form")
    within(equal_form) do
      fill_in "Descrição", with: description
      fill_in "Data", with: "2026-08-23"
      fill_in "Valor (R$)", with: "100,00"
      select fixture.fetch(:bruno).email, from: "Pago por"
      uncheck fixture.fetch(:bruno).email
      uncheck fixture.fetch(:carla).email
      click_button "Revisar divisão"
    end
    within("#group_dialog") { click_button "Confirmar despesa" }
  end

  def within_in(session_name, selector)
    Capybara.using_session(session_name) { within(selector) { yield } }
  end

  RSpec::Matchers.define :have_connected_group_stream do
    match do |page|
      page.has_css?("turbo-cable-stream-source[connected]", visible: :all, wait: Capybara.default_max_wait_time)
    end

    failure_message do |page|
      stream = page.evaluate_script("document.querySelector('turbo-cable-stream-source')?.outerHTML")
      logs = page.driver.browser.logs.get(:browser).map(&:message)
      "expected connected Action Cable stream; url=#{page.current_url.inspect}; text=#{page.text.inspect}; stream=#{stream.inspect}; browser_logs=#{logs.inspect}"
    end
  end
end
