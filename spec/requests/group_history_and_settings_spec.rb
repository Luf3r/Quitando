require "rails_helper"

RSpec.describe "Histórico e configurações do grupo" do
  it "renderiza os destinos por HTTP e rejeita página malformada" do
    user = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")
    post user_session_path, params: { user: { email: user.email, password: user.password } }

    get group_history_path(group)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Histórico")

    get group_settings_path(group)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Configurações")
    expect(response.body).to include("Transfira o ownership antes de sair.")

    get group_history_path(group, page: "zero")
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "reúne convites e ordenação de memberships nas Configurações" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    invited_user = create(:user, email: "carla@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    create(:group_invitation, group:, invited_user:, invited_by_user: owner, expires_at: 2.days.from_now)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Convidar pessoa")
    expect(response.body).to include("carla@example.com")
    expect(response.body).to include("Ordenar membros")
    expect(response.body).to include(group_memberships_order_path(group))
  end

  it "mantém Configurações de grupo arquivado somente para leitura e restauração" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    group.update!(archived_at: Time.current)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Restaurar grupo")
    expect(response.body).not_to include("Salvar nome")
    expect(response.body).not_to include("Convidar pessoa")
    expect(response.body).not_to include("Ordenar membros")
    expect(response.body).not_to include("Sair do grupo")
  end

  it "explica por que uma membership com saldo não pode ser inativada" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = create(:expense, group:, paid_by_user: owner, created_by_user: owner, amount_cents: 300)
    create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group)

    document = response.parsed_body
    member_row = document.css(".audit-list li").find { |row| row.text.include?(member.email) }
    expect(member_row.text).to include("saldo oficial diferente de zero")
    expect(member_row.at_css("button[disabled]")&.text).to include("Inativar membro")
  end

  it "explica por que um grupo aberto não pode ser arquivado" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = create(:expense, group:, paid_by_user: owner, created_by_user: owner, amount_cents: 300)
    create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group)

    document = response.parsed_body
    archive_section = document.at_css("#archive-title").parent
    expect(archive_section.text).to include("grupo não pode ser arquivado")
    expect(archive_section.at_css("button[disabled]")&.text).to include("Arquivar grupo")
  end
end
