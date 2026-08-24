require "rails_helper"

RSpec.describe "Visualização explicativa do grupo", type: :system do
  self.use_transactional_tests = false
  VISUALIZATION_PASSWORD = "visualizacao-password-segura".freeze

  before { driven_by(:chrome_headless) }

  after do
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: false)
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "no-preference" } ]
    )
    page.current_window.resize_to(1400, 1400)
    Capybara.reset_sessions!
    cleanup_fixture!
  end

  it "desenha com D3 os nós e arestas do payload do servidor" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page).to have_css("svg[data-visualization-graph]", count: 1)
    expect(page).to have_css("svg circle[data-user-id]", count: 2)
    expect(page).to have_css(
      "svg path[data-from-user-id='#{fixture.fetch(:member).id}'][data-to-user-id='#{fixture.fetch(:owner).id}']",
      count: 1
    )
    expect(page).to have_css("svg text[data-edge-label]", text: "R$ 3,00")
  end

  it "preserva centavos acima da precisão segura de Number sem cálculo monetário no cliente" do
    fixture = create_fixture!(with_expense: false)
    amount_cents = 9_007_199_254_740_993
    expense = create(
      :expense,
      group: fixture.fetch(:group),
      paid_by_user: fixture.fetch(:owner),
      created_by_user: fixture.fetch(:member),
      amount_cents:
    )
    create(:expense_share, expense:, user: fixture.fetch(:member), amount_owed_cents: amount_cents, position: 0)

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page).to have_css("svg[data-visualization-graph]", count: 1)
    expect(page.evaluate_script(<<~JS)).to eq(amount_cents.to_s)
      JSON.parse(
        document.getElementById("group_settlement_visualization").dataset.groupVisualizationPayloadValue
      ).layers.plan[0].amount_cents
    JS
    expect(find("#visualization_table_plan tr[data-amount-cents]")["data-amount-cents"]).to eq(amount_cents.to_s)
  end


  it "escolhe a camada bilateral quando o plano está vazio" do
    fixture = create_fixture!
    create(
      :payment,
      :confirmed,
      group: fixture.fetch(:group),
      from_user: fixture.fetch(:member),
      to_user: fixture.fetch(:owner),
      amount_cents: 300
    )

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page).to have_css("svg[data-layer='bilateral']", count: 1)
    expect(page).to have_css("svg path.visualization-edge", count: 1)
  end


  it "escolhe a camada histórica quando o plano e a compensação estão vazios" do
    fixture = create_fixture!
    reverse_expense = create(
      :expense,
      group: fixture.fetch(:group),
      paid_by_user: fixture.fetch(:member),
      created_by_user: fixture.fetch(:owner),
      amount_cents: 300
    )
    create(
      :expense_share,
      expense: reverse_expense,
      user: fixture.fetch(:owner),
      amount_owed_cents: 300,
      position: 0
    )

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page).to have_css("svg[data-layer='historical']", count: 1)
    expect(page).to have_css("svg path.visualization-edge", count: 2)
  end


  it "não cria SVG quando todas as camadas estão vazias" do
    fixture = create_fixture!(with_expense: false)

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page).to have_no_css("svg[data-visualization-graph]")
    expect(page).to have_text("Não há relações para desenhar neste estado")
    expect(page).to have_css("#visualization_table_plan")
    expect(page).to have_css("#visualization_table_bilateral")
    expect(page).to have_css("#visualization_table_historical")
  end


  it "torna erro estrutural visível sem ocultar as tabelas" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))
    expect(page).to have_css("svg[data-visualization-graph]")

    page.execute_script(<<~JS)
      const element = document.getElementById("group_settlement_visualization")
      element.dataset.groupVisualizationPayloadValue = JSON.stringify({ nodes: [], layers: {} })
      window.Stimulus.getControllerForElementAndIdentifier(element, "group-visualization").draw()
    JS

    expect(page).to have_css("#group_settlement_visualization[data-visualization-unavailable='true']")
    expect(page).to have_text("O mapa visual está indisponível")
    expect(page).to have_no_css("svg[data-visualization-graph]")
    expect(page).to have_css("#visualization_table_plan", visible: :visible)
    expect(page.driver.browser.logs.get(:browser).map(&:message).join).to include("Group visualization unavailable")
  end

  it "mantém a recuperação visível quando o módulo de desenho não carrega" do
    fixture = create_fixture!
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: true)
    page.driver.browser.execute_cdp("Network.clearBrowserCache")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*d3-selection*" ])

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page).to have_css("#group_settlement_visualization[data-visualization-unavailable='true']")
    expect(page).to have_text("O mapa visual está indisponível")
    expect(page).to have_no_css("svg[data-visualization-graph]")
    expect(page).to have_css("#visualization_table_plan", visible: :visible)
  end


  it "troca grafo e tabela pelo controle nativo e anuncia somente a ação do usuário" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    live_region = find("#visualization_layer_announcement", visible: :all)
    expect(live_region.text).to eq("")
    expect(page).to have_css("#visualization_panel_plan", visible: :visible)
    expect(page).to have_css("#visualization_panel_bilateral", visible: :hidden)
    expect(page).to have_css("#visualization_panel_historical", visible: :hidden)

    choose "Relações após compensação bilateral"

    expect(page).to have_css("svg[data-layer='bilateral']")
    expect(page).to have_css("#visualization_panel_plan", visible: :hidden)
    expect(page).to have_css("#visualization_panel_bilateral", visible: :visible)
    expect(live_region.text).to eq("Camada selecionada: relações após compensação bilateral.")
  end


  it "opera os controles pelo teclado e mantém SVG equivalente à tabela selecionada" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))
    plan_control = find("input[name='visualization_layer'][value='plan']")
    plan_control.send_keys(:arrow_right)

    expect(find("input[name='visualization_layer'][value='bilateral']")).to be_checked
    svg_edges = all("svg path.visualization-edge").map do |edge|
      [ edge["data-from-user-id"], edge["data-to-user-id"] ]
    end
    table_edges = all("#visualization_table_bilateral tbody tr[data-from-user-id]").map do |row|
      [ row["data-from-user-id"], row["data-to-user-id"] ]
    end
    expect(svg_edges).to eq(table_edges)
    svg = find("svg[data-visualization-graph]", visible: :all)
    expect(svg["aria-hidden"]).to eq("true")
    expect(svg["focusable"]).to eq("false")
    expect(svg["tabindex"]).to be_nil
  end


  it "respeita movimento reduzido e usa contraste AA com padrões além de cor" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    colors = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.documentElement)
        return {
          canvas: style.getPropertyValue("--visualization-canvas").trim(),
          nodeFill: style.getPropertyValue("--visualization-node-fill").trim(),
          nodeStroke: style.getPropertyValue("--visualization-node-stroke").trim(),
          edge: style.getPropertyValue("--visualization-edge").trim(),
          text: style.getPropertyValue("--visualization-text").trim(),
          focus: style.getPropertyValue("--visualization-focus").trim()
        }
      })()
    JS
    expect(colors.values).to all(match(/\A#[0-9a-f]{6}\z/i))
    expect(contrast_ratio(colors.fetch("text"), colors.fetch("canvas"))).to be >= 4.5
    expect(contrast_ratio(colors.fetch("edge"), colors.fetch("canvas"))).to be >= 3.0
    expect(contrast_ratio(colors.fetch("nodeStroke"), colors.fetch("nodeFill"))).to be >= 3.0
    expect(contrast_ratio(colors.fetch("focus"), colors.fetch("canvas"))).to be >= 3.0
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.visualization-edge')).transitionDuration"))
      .to eq("0.18s")

    choose "Relações após compensação bilateral"
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.visualization-edge')).strokeDasharray"))
      .not_to eq("none")
    choose "Relações históricas agregadas"
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.visualization-edge')).strokeDasharray"))
      .not_to eq("none")

    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ]
    )
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.visualization-edge')).transitionDuration"))
      .to eq("0s")
  end


  it "mantém a tabela antes do grafo e o SVG dentro do viewport móvel" do
    fixture = create_fixture!
    page.current_window.resize_to(390, 844)

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    expect(page.evaluate_script(<<~JS)).to be(true)
      document.getElementById("visualization_panel_plan").compareDocumentPosition(
        document.getElementById("visualization_graph")
      ) === Node.DOCUMENT_POSITION_FOLLOWING
    JS
    expect(page.evaluate_script(<<~JS)).to be(true)
      document.querySelector("svg[data-visualization-graph]").getBoundingClientRect().width <=
        document.documentElement.clientWidth
    JS
    expect(page).to have_css("#visualization_panel_plan", visible: :visible)
  end

  it "mantém a tabela selecionada ao lado do grafo no desktop" do
    fixture = create_fixture!
    page.current_window.resize_to(1400, 1000)

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    table_rect = page.evaluate_script("document.getElementById('visualization_panel_plan').getBoundingClientRect().toJSON()")
    graph_rect = page.evaluate_script("document.getElementById('visualization_graph_region').getBoundingClientRect().toJSON()")
    expect(table_rect.fetch("right")).to be <= graph_rect.fetch("left")
    expect(table_rect.fetch("top")).to be_within(2).of(graph_rect.fetch("top"))
  end


  it "foca o diálogo e devolve foco ao acionador por botão e Escape" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))
    find_link("Marcar como enviado").click
    expect(page).to have_css("#group_dialog_shell[open]")
    expect(page.evaluate_script("document.activeElement?.id")).to eq("payment_amount_text"),
      page.evaluate_script("document.activeElement?.outerHTML")

    page.execute_script(<<~JS)
      const dialog = document.getElementById("group_dialog_shell")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(dialog, "group-dialog")
      const negativeTarget = document.createElement("button")
      negativeTarget.id = "negative_focus_target"
      negativeTarget.textContent = "Controle negativo de foco"
      document.body.append(negativeTarget)
      controller.returnFocus = negativeTarget
      dialog.removeEventListener("close", controller.onClose)
    JS
    click_button "Fechar"
    expect(page).to have_no_css("#group_dialog_shell[open]")
    expect(page.evaluate_script("document.activeElement?.id")).not_to eq("negative_focus_target")

    visit group_path(fixture.fetch(:group))
    find_link("Marcar como enviado").click
    expect(find("#payment_amount_text")).to match_css(":focus")
    click_button "Fechar"
    expect(find_link("Marcar como enviado")).to match_css(":focus")

    find_link("Marcar como enviado").click
    find("#group_dialog_shell").send_keys(:escape)
    expect(page).to have_no_css("#group_dialog_shell[open]")
    expect(find_link("Marcar como enviado")).to match_css(":focus")
  end

  it "mantém IDs e controles únicos quando um report obsoleto atualiza o diálogo" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))
    find_link("Marcar como enviado").click
    expect(page).to have_css("#group_dialog_shell[open]")

    ExpenseCreator.call(
      group_id: fixture.fetch(:group).id,
      created_by_user_id: fixture.fetch(:owner).id,
      paid_by_user_id: fixture.fetch(:owner).id,
      description: "Mudança concorrente",
      occurred_on: Date.new(2026, 8, 23),
      amount_text: "1,00",
      split: {
        type: :exact,
        shares: [ { user_id: fixture.fetch(:member).id, amount_text: "1,00" } ]
      }
    )
    within("#group_dialog") { click_button "Marcar como enviado" }

    expect(page).to have_text("Pagamento não registrado")
    expect(page).to have_css("#dialog_visualization_table_plan")
    expect(all("[id='group_dashboard_financial_summary']", visible: :all).size).to eq(1)
    expect(all("[id='group_settlement_visualization']", visible: :all).size).to eq(1)
    expect(all("input[name='visualization_layer']", visible: :all).size).to eq(3)
  end

  private

  def create_fixture!(with_expense: true)
    suffix = SecureRandom.hex(6)
    owner = create(
      :user,
      email: "ana-visualizacao-#{suffix}@example.com",
      password: VISUALIZATION_PASSWORD,
      password_confirmation: VISUALIZATION_PASSWORD
    )
    member = create(
      :user,
      email: "bruno-visualizacao-#{suffix}@example.com",
      password: VISUALIZATION_PASSWORD,
      password_confirmation: VISUALIZATION_PASSWORD
    )
    group = create(:group, name: "Visualização #{suffix}")
    create(:membership, group:, user: owner, role: :owner, position: 0)
    create(:membership, group:, user: member, position: 1)
    if with_expense
      expense = create(:expense, group:, paid_by_user: owner, created_by_user: member, amount_cents: 300)
      create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)
    end

    @fixture = { group:, owner:, member: }
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
    User.where(id: @fixture.values_at(:owner, :member).map(&:id)).delete_all
  ensure
    @fixture = nil
  end

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: VISUALIZATION_PASSWORD
    find('input[type="submit"]').click
    expect(page).to have_current_path(root_path)
  end

  def contrast_ratio(first_hex, second_hex)
    first_luminance = relative_luminance(first_hex)
    second_luminance = relative_luminance(second_hex)
    lighter, darker = [ first_luminance, second_luminance ].max, [ first_luminance, second_luminance ].min

    (lighter + 0.05) / (darker + 0.05)
  end

  def relative_luminance(hex)
    hex.delete_prefix("#").scan(/../).map { |component| component.to_i(16) / 255.0 }.map do |channel|
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end.then { |red, green, blue| (0.2126 * red) + (0.7152 * green) + (0.0722 * blue) }
  end
end
