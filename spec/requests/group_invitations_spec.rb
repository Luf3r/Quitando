require "rails_helper"

RSpec.describe "Group invitations" do
  describe "GET /invitations" do
    it "mostra somente convites pending do usuário autenticado" do
      invited_user = create(:user, email: "bia@example.com")
      visible_group = create(:group, name: "Grupo visível")
      hidden_group = create(:group, name: "Grupo oculto")
      visible = create(:group_invitation, group: visible_group, invited_user:, expires_at: 2.days.from_now)
      hidden = create(:group_invitation, group: hidden_group, expires_at: 2.days.from_now)

      post user_session_path, params: { user: { email: invited_user.email, password: invited_user.password } }
      get "/invitations"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(visible.group.name)
      expect(response.body).not_to include(hidden.group.name)
      expect(response.body).to include("Aceitar convite")
      expect(response.body).to include("Recusar convite")
    end
  end

  describe "POST /groups/:group_id/invitations" do
    it "cria convite para o e-mail exato e redireciona com 303" do
      owner = create(:user, email: "ana@example.com")
      invited_user = create(:user, email: "bia@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }

      expect {
        post "/groups/#{group.id}/invitations", params: { invitation: { email: invited_user.email } }
      }.to change(GroupInvitation, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/groups/#{group.id}")
      expect(GroupInvitation.last).to have_attributes(invited_user_id: invited_user.id, status: "pending")
    end

    it "não enumera contas quando o e-mail não existe" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      post "/groups/#{group.id}/invitations", params: { invitation: { email: "ausente@example.com" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Não foi possível concluir esta ação")
      expect(GroupInvitation.where(group:)).to be_empty
    end
  end

  describe "POST /invitations/:id/accept" do
    it "permite que o convidado aceite e redireciona com 303" do
      invited_user = create(:user, email: "bia@example.com")
      invitation = create(:group_invitation, invited_user:, expires_at: 2.days.from_now)

      post user_session_path, params: { user: { email: invited_user.email, password: invited_user.password } }
      post "/invitations/#{invitation.id}/accept"

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/groups/#{invitation.group_id}")
      expect(invitation.reload).to be_accepted
      expect(Membership.where(group: invitation.group, user: invited_user, status: :active)).to exist
    end
  end

  describe "POST /invitations/:id/decline" do
    it "permite que o convidado recuse" do
      invited_user = create(:user, email: "bia@example.com")
      invitation = create(:group_invitation, invited_user:, expires_at: 2.days.from_now)

      post user_session_path, params: { user: { email: invited_user.email, password: invited_user.password } }
      post "/invitations/#{invitation.id}/decline"

      expect(response).to have_http_status(:see_other)
      expect(invitation.reload).to be_declined
    end
  end

  describe "POST /groups/:group_id/invitations/:id/revoke" do
    it "permite que owner revogue convite pending" do
      owner = create(:user, email: "ana@example.com")
      group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
      invitation = create(:group_invitation, group:, invited_by_user: owner, expires_at: 2.days.from_now)

      post user_session_path, params: { user: { email: owner.email, password: owner.password } }
      post "/groups/#{group.id}/invitations/#{invitation.id}/revoke"

      expect(response).to have_http_status(:see_other)
      expect(invitation.reload).to be_revoked
    end
  end
end
