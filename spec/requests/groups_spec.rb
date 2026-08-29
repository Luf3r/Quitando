require "rails_helper"

RSpec.describe "Groups" do
  describe "GET /groups" do
    it "redireciona visitante não autenticado para entrar" do
      get "/groups"

      expect(response).to redirect_to(new_user_session_path)
    end

    it "mostra somente grupos com membership ativo do usuário autenticado" do
      user = create(:user, email: "ana@example.com")
      visible_group = GroupCreator.call(owner_user_id: user.id, name: "Casa da Ana")
      other_user = create(:user, email: "bia@example.com")
      hidden_group = GroupCreator.call(owner_user_id: other_user.id, name: "Casa da Bia")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(visible_group.name)
      expect(response.body).not_to include(hidden_group.name)
    end

    it "coloca o acesso à caixa de convites antes da lista de grupos" do
      user = create(:user, email: "ana@example.com")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups"

      headings = Nokogiri::HTML(response.body).css("section h2").map(&:text)
      expect(headings.index("Convites recebidos")).to be < headings.index("Seus grupos")
      expect(response.body).to include('href="/invitations"')
    end

    it "não mostra convite terminal no resumo nem expõe suas ações" do
      user = create(:user, email: "ana@example.com")
      invitation = create(:group_invitation, :declined, invited_user: user)

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(invitation.group.name)
      expect(response.body).not_to include("/invitations/#{invitation.id}/accept")
      expect(response.body).not_to include("/invitations/#{invitation.id}/decline")
    end

    it "ignora convite terminal com expires_at passado sem alterar seu estado" do
      user = create(:user, email: "ana@example.com")
      invitation = create(:group_invitation, :declined, invited_user: user, expires_at: 1.minute.ago)
      declined_at = invitation.declined_at

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups"

      expect(response).to have_http_status(:ok)
      expect(invitation.reload).to have_attributes(status: "declined", declined_at:)
    end
  end

  describe "POST /groups" do
    it "cria o grupo com o usuário autenticado como owner e redireciona com 303" do
      user = create(:user, email: "ana@example.com")

      post user_session_path, params: { user: { email: user.email, password: user.password } }

      expect do
        post "/groups", params: { group: { name: "Apartamento" } }
      end.to change(Group, :count).by(1)

      group = Group.order(:created_at).last
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/groups")
      expect(group.memberships.find_by(user: user)).to have_attributes(role: "owner", status: "active")
    end

    it "responde com refresh Turbo Stream depois de criar o grupo" do
      user = create(:user, email: "ana@example.com")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      post "/groups", params: { group: { name: "Apartamento" } }, headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include('action="refresh"')
    end
  end

  describe "GET /groups/:id" do
    it "mostra um grupo que pertence ao usuário autenticado" do
      user = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get group_path(group)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Apartamento")
      expect(response.body).to include("Saldo oficial")
      expect(response.body).to include("Resumo")
    end

    it "renderiza o Resumo sem o payload do grafo histórico" do
      user = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get group_path(group)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("data-group-visualization-payload-value")
      expect(response.body).not_to include("group_settlement_visualization")
    end

    it "oferece no Resumo uma sugestão acionável para o devedor" do
      ana = create(:user, email: "ana@example.com")
      bruno = create(:user, email: "bruno@example.com")
      group = GroupCreator.call(owner_user_id: ana.id, name: "Apartamento")
      create(:membership, group:, user: bruno, position: 1)
      expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 300)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 300, position: 0)

      post user_session_path, params: { user: { email: bruno.email, password: bruno.password } }
      get group_path(group)

      document = response.parsed_body
      expect(document.at_css("#group_dashboard_financial_summary").text).to include("bruno@example.com deve enviar")
      expect(document.at_css("a[href='#{new_group_payment_path(group, to_user_id: ana.id)}']").text).to include("Marcar como enviado")
    end

    it "habilita refresh por morph apenas no shell permanente do grupo" do
      user = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get group_plan_path(group)

      expect(response.body).to include('name="turbo-refresh-method" content="morph"')
      expect(response.body).to include('name="turbo-refresh-scroll" content="preserve"')
      expect(response.body).to include('id="group_remote_notice"')
      expect(response.body).to include('aria-live="polite"')
      expect(response.body).to include('id="group_dialog"')
      expect(response.body).to include('channel="GroupsChannel"')
      expect(response.body).to include('data-controller="group-realtime-status"')
    end


    it "renderiza tabelas semânticas e JSON equivalentes para as três camadas" do
      owner = create(:user, email: "ana@example.com")
      member = create(:user, email: "bruno@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      create(:membership, group:, user: member, position: 1)
      expense = create(
        :expense,
        group:,
        paid_by_user: owner,
        created_by_user: member,
        amount_cents: 300
      )
      create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)

      post user_session_path, params: { user: { email: member.email, password: member.password } }
      get group_plan_path(group)

      document = response.parsed_body
      payload_element = document.at_css("[data-group-visualization-payload-value]")
      payload = JSON.parse(payload_element["data-group-visualization-payload-value"])

      %w[historical bilateral plan].each do |layer|
        table = document.at_css("#visualization_table_#{layer}")
        expect(table.css("thead th").map(&:text)).to eq([ "De", "Para", "Valor", "Ação" ])
        table_edges = table.css("tbody tr[data-from-user-id]").map do |row|
          {
            "from_user_id" => row["data-from-user-id"],
            "to_user_id" => row["data-to-user-id"],
            "amount_cents" => row["data-amount-cents"],
            "formatted_amount" => row.at_css("data[value]").text
          }
        end
        expect(table_edges).to eq(payload.fetch("layers").fetch(layer))
      end
      expect(document.at_css("#visualization_table_plan").text).to include("Marcar como enviado")
      expect(document.at_css("details#settlement_trace")).not_to have_attribute("open")
      expect(document.at_css("details#settlement_trace summary").text).to include("Como chegamos a este plano?")
    end


    it "explica quando o plano líquido muda o destinatário histórico" do
      ana = create(:user, email: "ana@example.com")
      diego = create(:user, email: "diego@example.com")
      carla = create(:user, email: "carla@example.com")
      group = GroupCreator.call(owner_user_id: ana.id, name: "Viagem")
      create(:membership, group:, user: diego, position: 1)
      create(:membership, group:, user: carla, position: 2)
      lodging = create(
        :expense,
        group:,
        paid_by_user: ana,
        created_by_user: carla,
        amount_cents: 600,
        description: "Hospedagem"
      )
      create(:expense_share, expense: lodging, user: ana, amount_owed_cents: 300, position: 0)
      create(:expense_share, expense: lodging, user: diego, amount_owed_cents: 300, position: 1)
      groceries = create(
        :expense,
        group:,
        paid_by_user: diego,
        created_by_user: diego,
        amount_cents: 300,
        description: "Mercado"
      )
      create(:expense_share, expense: groceries, user: carla, amount_owed_cents: 300, position: 0)

      post user_session_path, params: { user: { email: carla.email, password: carla.password } }
      get group_plan_path(group)

      document = response.parsed_body
      explanation = document.at_css("[data-counterintuitive-explanation]").text.squish
      expect(explanation).to include("carla@example.com deve ao grupo. Pagar ana@example.com")
      expect(document.at_css("#visualization_table_historical").text.squish).to include("carla@example.com diego@example.com")
      expect(document.at_css("#visualization_table_plan").text.squish).to include("carla@example.com ana@example.com")
    end

    it "oferece a ordenação de memberships por formulário HTML ao owner" do
      owner = create(:user, email: "ana@example.com")
      member = create(:user, email: "bia@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      create(:membership, group:, user: member, position: 1)

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      get "/groups/#{group.id}"

      expect(response.body).to include("Ordenar membros")
      expect(response.body).to include("/groups/#{group.id}/memberships/order")
    end

    it "mantém grupo arquivado legível, mas só oferece a restauração como mutação" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      group.update!(archived_at: Time.current)

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      get "/groups/#{group.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Restaurar grupo")
      expect(response.body).not_to include("Nova despesa")
      expect(response.body).not_to include("Renomear grupo")
      expect(response.body).not_to include("Convidar pessoa")
    end

    it "não apresenta como pendente um convite que venceu no instante limite" do
      owner = create(:user, email: "ana@example.com")
      invited_user = create(:user, email: "bia@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      invitation = create(:group_invitation, group:, invited_user:, invited_by_user: owner, expires_at: Time.current)

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      get "/groups/#{group.id}"

      expect(response.body).not_to include("/groups/#{group.id}/invitations/#{invitation.id}/revoke")
    end

    it "não encontra grupo de outro usuário" do
      user = create(:user, email: "ana@example.com")
      other_user = create(:user, email: "bia@example.com")
      other_group = GroupCreator.call(owner_user_id: other_user.id, name: "Apartamento da Bia")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups/#{other_group.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "rejeita UUID malformado sem consultar grupos" do
      user = create(:user, email: "ana@example.com")
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args, payload|
        queries << payload[:sql] if payload[:sql].match?(/FROM "groups"/)
      end

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups/nao-e-um-uuid"

      expect(response).to have_http_status(:not_found)
      expect(queries).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  describe "PATCH /groups/:id" do
    it "permite que owner ativo renomeie o grupo e redireciona com 303" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      patch "/groups/#{group.id}", params: { group: { name: "Apartamento novo" } }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/groups/#{group.id}")
      expect(group.reload.name).to eq("Apartamento novo")
    end

    it "responde com refresh Turbo Stream depois de renomear" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      patch "/groups/#{group.id}", params: { group: { name: "Apartamento novo" } }, headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include('action="refresh"')
      expect(group.reload.name).to eq("Apartamento novo")
    end

    it "recusa membro ativo que não é owner" do
      owner = create(:user, email: "ana@example.com")
      member = create(:user, email: "bia@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      create(:membership, group:, user: member, role: :member, position: 1)

      post user_session_path, params: { user: { email: member.email, password: member.password } }
      patch "/groups/#{group.id}", params: { group: { name: "Tentativa" } }

      expect(response).to have_http_status(:forbidden)
      expect(group.reload.name).to eq("Apartamento")
    end

    it "devolve 422 para nome inválido sem alterar o grupo" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      patch "/groups/#{group.id}", params: { group: { name: "   " } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Não foi possível concluir esta ação")
      expect(group.reload.name).to eq("Apartamento")
    end

    it "devolve 422 para grupo arquivado" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      group.update!(archived_at: Time.current)

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      patch "/groups/#{group.id}", params: { group: { name: "Novo nome" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(group.reload.name).to eq("Apartamento")
    end
  end

  describe "POST /groups/:id/archive" do
    it "arquiva grupo empty por owner e restaura por POST" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      post "/groups/#{group.id}/archive"

      expect(response).to have_http_status(:see_other)
      expect(group.reload.archived_at).to be_present

      post "/groups/#{group.id}/restore"

      expect(response).to have_http_status(:see_other)
      expect(group.reload.archived_at).to be_nil
    end

    it "responde com refresh Turbo Stream ao arquivar e restaurar" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      post "/groups/#{group.id}/archive", headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include('action="refresh"')
      expect(group.reload.archived_at).to be_present

      post "/groups/#{group.id}/restore", headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include('action="refresh"')
      expect(group.reload.archived_at).to be_nil
    end
  end

  it "mostra controles de arquivamento ao owner" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get "/groups/#{group.id}"

    expect(response.body).to include("Arquivar grupo")
  end
end
