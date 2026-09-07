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
    expect(response.body).to include("Transfira a responsabilidade antes de sair.")

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

    document = response.parsed_body
    owner_row = document.css(".settings-member").find { |row| row.text.include?(owner.email) }
    invitation_row = document.css(".settings-invitation").find { |row| row.text.include?(invited_user.email) }

    expect(owner_row.css("dt").map(&:text)).to include("Nome", "E-mail", "Papel", "Estado")
    expect(owner_row.at_css("[data-status='owner'][data-tone='neutral']").text).to include("Responsável pelo grupo")
    expect(owner_row.at_css("[data-status='active'][data-tone='positive']").text).to include("Ativo")
    expect(invitation_row.css("dt").map(&:text)).to include("E-mail", "Estado", "Enviado em")
    expect(invitation_row.at_css("[data-status='pending'][data-tone='attention']").text).to include("Pendente")
    expect(document.xpath("//text()[normalize-space(.)='.' or normalize-space(.)=';']")).to be_empty
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
    member_row = document.css(".settings-member").find { |row| row.text.include?(member.email) }
    expect(member_row.text).to include("saldo oficial diferente de zero")
    blocked_action = member_row.at_css("button[disabled][aria-describedby]")
    expect(blocked_action&.text).to include("Inativar membro")
    expect(member_row.at_css("##{blocked_action['aria-describedby']}").text).to include("saldo oficial diferente de zero")
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

  it "mostra o histórico enviado ao owner ativo sem ações nos convites terminais" do
    owner = create(:user, email: "ana@example.com")
    invited_user = create(:user, email: "carla@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    terminal = create(:group_invitation, :revoked, group:, invited_user:, invited_by_user: owner)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Histórico de convites enviados", invited_user.email, "Revogado")
    expect(response.body).not_to include("/groups/#{group.id}/invitations/#{terminal.id}/revoke")
  end

  it "não mostra o histórico enviado para membro ativo que não é owner" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    invited_user = create(:user, email: "carla@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    create(:group_invitation, :revoked, group:, invited_user:, invited_by_user: owner)

    post user_session_path, params: { user: { email: member.email, password: member.password } }
    get group_settings_path(group)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Histórico de convites enviados", invited_user.email)
  end

  it "rejeita página malformada das configurações antes de consultar convites" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:group_invitation, group:, invited_by_user: owner)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    queries = sql_queries_for("group_invitations") { get group_settings_path(group, page: "zero") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(queries).to be_empty
  end

  it "mantém a paginação de convites enviados independente e abre o histórico ao paginá-lo" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    26.times { create(:group_invitation, group:, invited_by_user: owner, expires_at: 2.days.from_now) }
    26.times { create(:group_invitation, :revoked, group:, invited_by_user: owner) }

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get group_settings_path(group, pending_page: "1", closed_page: "2")

    expect(response).to have_http_status(:ok)
    document = response.parsed_body
    expect(document.at_css("details#closed-invitations-history[open]")).to be_present
    closed_navigation = document.at_css("nav[aria-label='Paginação dos convites enviados encerrados']")
    expect(closed_navigation.at_css("a", text: "Anterior")["href"]).to include("pending_page=1", "closed_page=1", "#closed-invitations-history")
  end

  private

  def sql_queries_for(*tables)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args, payload|
      queries << payload[:sql] if tables.any? { |table| payload[:sql].match?(/FROM \"#{table}\"/) }
    end

    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
