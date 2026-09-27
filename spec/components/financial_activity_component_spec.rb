require "rails_helper"
require "view_component/test_helpers"

RSpec.describe FinancialActivityComponent, type: :component do
  include ViewComponent::TestHelpers

  it "estrutura uma despesa compacta sem usar pontuação como elemento de layout" do
    creator = create(:user, name: "Ana Martins")
    payer = create(:user, name: "Bruno Souza")
    group = GroupCreator.call(owner_user_id: creator.id, name: "Viagem")
    create(:membership, group:, user: payer, position: 1)
    expense = create(
      :expense,
      group:,
      created_by_user: creator,
      paid_by_user: payer,
      description: "Hospedagem na serra",
      amount_cents: 12_345
    )
    entry = GroupHistoryQuery::Entry.new(
      kind: :expense,
      record: expense,
      occurred_at: expense.created_at,
      cycles: [ :recorded ]
    )

    render_inline(described_class.new(entry:, group:, compact: true))

    activity = page.find("article.financial-activity--compact[data-entry-kind='expense']")
    expect(activity).to have_css(".financial-activity__type", text: "Despesa")
    expect(activity).to have_link("Hospedagem na serra", href: "/groups/#{group.id}/expenses/#{expense.id}")
    expect(activity).to have_css(".financial-activity__amount", text: "R$ 123,45")
    expect(activity).to have_css("[data-activity-field='paid-by']", text: "Bruno Souza")
    expect(activity).to have_css("[data-activity-field='created-by']", text: "Ana Martins")
    expect(activity).to have_css(".ui-badge[data-status='active']", text: "Ativa")
    expect(punctuation_only_text_nodes).to be_empty
  end

  it "separa origem, destino, estado e ação de um pagamento" do
    receiver = create(:user, name: "Ana Martins")
    sender = create(:user, name: "Bruno Souza")
    group = GroupCreator.call(owner_user_id: receiver.id, name: "Viagem")
    create(:membership, group:, user: sender, position: 1)
    payment = create(
      :payment,
      :cancelled,
      group:,
      from_user: sender,
      to_user: receiver,
      reported_by_user: sender,
      amount_cents: 8_500
    )
    entry = GroupHistoryQuery::Entry.new(
      kind: :payment,
      record: payment,
      occurred_at: payment.created_at,
      cycles: [ :cancelled ]
    )

    render_inline(described_class.new(entry:, group:))

    activity = page.find("article.financial-activity[data-entry-kind='payment']")
    expect(activity).to have_css("[data-activity-field='from']", text: "Bruno Souza")
    expect(activity).to have_css("[data-activity-field='to']", text: "Ana Martins")
    expect(activity).to have_css(".ui-badge[data-status='cancelled'][data-tone='negative']", text: "Cancelado")
    expect(activity).to have_link("Ver detalhes", href: "/groups/#{group.id}/payments/#{payment.id}")
    expect(punctuation_only_text_nodes).to be_empty
  end

  def punctuation_only_text_nodes
    Nokogiri::HTML.fragment(page.native.to_html).xpath(".//text()[normalize-space(.) = '.' or normalize-space(.) = ';']")
  end
end
