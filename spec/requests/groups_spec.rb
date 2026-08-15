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
  end

  describe "GET /groups/:id" do
    it "mostra um grupo que pertence ao usuário autenticado" do
      user = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")

      post user_session_path, params: { user: { email: user.email, password: user.password } }
      get "/groups/#{group.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Apartamento")
      expect(response.body).to include("Saldo oficial")
      expect(response.body).to include("Plano líquido")
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
  end

  it "mostra controles de arquivamento ao owner" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    get "/groups/#{group.id}"

    expect(response.body).to include("Arquivar grupo")
  end
end
