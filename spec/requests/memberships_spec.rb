require "rails_helper"

RSpec.describe "Memberships" do
  it "rejeita ID de membership malformado antes de consultar o grupo ou memberships" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    queries = sql_queries_for("groups", "memberships") do
      post "/groups/#{group.id}/memberships/nao-e-um-uuid/deactivate"
    end

    expect(response).to have_http_status(:not_found)
    expect(queries).to be_empty
  end

  it "permite que membro ativo saia do grupo por POST" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    membership = create(:membership, group:, user: member, position: 1)

    post user_session_path, params: { user: { email: member.email, password: member.password } }
    post "/groups/#{group.id}/memberships/#{membership.id}/deactivate"

    expect(response).to have_http_status(:see_other)
    expect(membership.reload).to be_inactive
  end

  it "permite que owner reative a mesma membership por POST" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    membership = create(:membership, group:, user: member, status: :inactive, position: 1)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/memberships/#{membership.id}/reactivate"

    expect(response).to have_http_status(:see_other)
    expect(membership.reload).to be_active
  end

  it "permite que owner transfira ownership para membro ativo" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    membership = create(:membership, group:, user: member, position: 1)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/memberships/#{membership.id}/transfer_ownership"

    expect(response).to have_http_status(:see_other)
    expect(membership.reload).to be_owner
    expect(group.memberships.find_by(user: owner)).to be_member
  end

  it "permite que owner ordene todas as memberships" do
    owner = create(:user, email: "ana@example.com")
    first = create(:user, email: "bia@example.com")
    second = create(:user, email: "clara@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    first_membership = create(:membership, group:, user: first, position: 1)
    second_membership = create(:membership, group:, user: second, position: 2)
    owner_membership = group.memberships.find_by(user: owner)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    patch "/groups/#{group.id}/memberships/order", params: { membership: { ids: [ second_membership.id, owner_membership.id, first_membership.id ] } }

    expect(response).to have_http_status(:see_other)
    expect(group.memberships.order(:position).pluck(:id)).to eq([ second_membership.id, owner_membership.id, first_membership.id ])
  end

  private

  def sql_queries_for(*tables)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args, payload|
      queries << payload[:sql] if tables.any? { |table| payload[:sql].match?(/FROM "#{table}"/) }
    end

    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
