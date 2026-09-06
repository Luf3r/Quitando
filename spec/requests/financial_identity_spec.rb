require "rails_helper"

RSpec.describe "Identidade por nome nas superfícies financeiras" do
  let(:owner) { create(:user, name: "Ágata Évora Silva") }
  let(:member) { create(:user, name: "João da Conceição") }
  let(:group) { GroupCreator.call(owner_user_id: owner.id, name: "Casa") }
  let!(:membership) { create(:membership, group:, user: member, position: 1) }
  let!(:expense) do
    create(:expense, group:, paid_by_user: owner, created_by_user: member, amount_cents: 300).tap do |record|
      create(:expense_share, expense: record, user: member, amount_owed_cents: 300, position: 0)
    end
  end
  let!(:payment) { create(:payment, group:, from_user: member, to_user: owner, amount_cents: 100) }

  before do
    post user_session_path, params: { user: { email: member.email, password: member.password } }
  end

  {
    "lista de grupos" => -> { groups_path },
    "resumo" => -> { group_path(group) },
    "plano e cálculo" => -> { group_plan_path(group) },
    "histórico" => -> { group_history_path(group) },
    "formulário de despesa" => -> { new_group_expense_path(group) },
    "detalhe de despesa" => -> { group_expense_path(group, expense) },
    "formulário de correção" => -> { group_expense_correction_path(group, expense) },
    "report de pagamento" => -> { new_group_payment_path(group, to_user_id: owner.id) },
    "detalhe de pagamento" => -> { group_payment_path(group, payment) }
  }.each do |surface, path|
    it "mostra nomes completos e não e-mails em #{surface}" do
      get instance_exec(&path)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(owner.name, member.name)
      expect(response.body).not_to include(owner.email, member.email)
    end
  end

  it "preserva nomes completos nas três tabelas HTML e na legenda do grafo" do
    get group_plan_path(group)

    document = response.parsed_body
    %w[plan bilateral historical].each do |layer|
      table = document.at_css("#visualization_table_#{layer}")
      expect(table.text).to include(owner.name, member.name)
      expect(table.ancestors.any? { |ancestor| ancestor.key?("hidden") }).to be(false)
    end
    expect(document.at_css("#visualization_participants").text).to include(owner.name, member.name)
  end

  it "mantém nome primário, e-mail secundário e convite por e-mail na administração" do
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group)

    document = response.parsed_body
    row = document.css(".settings-member").find { |item| item.text.include?(member.email) }
    name_label = row.css("dt").find { |label| label.text == "Nome" }
    email_label = row.css("dt").find { |label| label.text == "E-mail" }
    expect(name_label.next_element.text).to eq(member.name)
    expect(email_label.next_element.text).to eq(member.email)
    expect(document.at_css('input[name="invitation[email]"][type="email"]')).to be_present
  end
end
