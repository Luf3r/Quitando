require "rails_helper"

RSpec.describe "Expenses" do
  it "cria despesa de divisão igual por POST e redireciona com 303" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    expect {
      post "/groups/#{group.id}/expenses", params: { expense: { description: "Mercado", occurred_on: "2026-08-14", amount_text: "20,00", paid_by_user_id: owner.id, split_type: "equal", participant_user_ids: [ owner.id, member.id ] } }
    }.to change(Expense, :count).by(1)

    expect(response).to have_http_status(:see_other)
  end

  it "corrige financeiramente anulando a original e criando substituta" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, member.id ] })

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/expenses/#{expense.id}/correct", params: { correction: { reason: "Valor correto", description: "Mercado", amount_text: "25,00", paid_by_user_id: owner.id, split_type: "equal", participant_user_ids: [ owner.id, member.id ], expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid } }

    expect(response).to have_http_status(:see_other)
    expect(expense.reload.voided_at).to be_present
    expect(Expense.where(replaces_expense_id: expense.id)).to exist
  end

  it "devolve 409 com os valores da correção e o plano atual quando a versão está obsoleta" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, member.id ] })

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/expenses/#{expense.id}/correct", params: { correction: { reason: "Valor correto", description: "Mercado corrigido", amount_text: "25,00", paid_by_user_id: owner.id, split_type: "equal", participant_user_ids: [ owner.id, member.id ], expected_financial_state_version: group.reload.financial_state_version - 1, idempotency_key: SecureRandom.uuid } }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Mercado corrigido")
    expect(response.body).to include("Plano líquido")
    expect(expense.reload.voided_at).to be_nil
  end

  it "edita a descrição com revisão auditável" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    expense = create(:expense, group:, created_by_user: owner, paid_by_user: owner, description: "Mercado")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    patch "/groups/#{group.id}/expenses/#{expense.id}/description", params: { expense: { description: "Mercado semanal" } }

    expect(response).to have_http_status(:see_other)
    expect(expense.reload.description).to eq("Mercado semanal")
    expect(expense.expense_description_revisions.last).to have_attributes(previous_description: "Mercado", new_description: "Mercado semanal", actor_user_id: owner.id)
  end

  it "devolve 422 quando a edição não altera a descrição" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    expense = create(:expense, group:, created_by_user: owner, paid_by_user: owner, description: "Mercado")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    patch "/groups/#{group.id}/expenses/#{expense.id}/description", params: { expense: { description: "Mercado" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(expense.expense_description_revisions).to be_empty
  end

  it "devolve 403 quando membro sem papel permitido tenta editar a descrição" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = create(:expense, group:, created_by_user: owner, paid_by_user: owner, description: "Mercado")

    post user_session_path, params: { user: { email: member.email, password: member.password } }
    patch "/groups/#{group.id}/expenses/#{expense.id}/description", params: { expense: { description: "Mercado semanal" } }

    expect(response).to have_http_status(:forbidden)
    expect(expense.reload.description).to eq("Mercado")
  end

  it "preserva descrição e valor submetidos ao devolver 422" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/expenses", params: { expense: { description: "Mercado especial", occurred_on: "2026-08-14", amount_text: "invalido", paid_by_user_id: owner.id, split_type: "equal", participant_user_ids: [ owner.id ] } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Mercado especial")
    expect(response.body).to include("invalido")
    expect(Expense.where(group:)).to be_empty
  end

  it "cria despesa de divisão exata por POST" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/expenses", params: { expense: { description: "Mercado", occurred_on: "2026-08-14", amount_text: "20,00", paid_by_user_id: owner.id, split_type: "exact", participant_user_ids: [], shares: [ { user_id: owner.id, amount_text: "10,00" }, { user_id: member.id, amount_text: "10,00" } ] } }

    expect(response).to have_http_status(:see_other)
    expect(Expense.last.expense_shares.sum(:amount_owed_cents)).to eq(2_000)
  end

  it "mostra creator e pagador separados no detalhe" do
    creator = create(:user, email: "ana@example.com")
    payer = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: creator.id, name: "Apartamento")
    create(:membership, group:, user: payer, position: 1)
    expense = create(:expense, group:, created_by_user: creator, paid_by_user: payer)

    post user_session_path, params: { user: { email: creator.email, password: creator.password } }
    get "/groups/#{group.id}/expenses/#{expense.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("pago por bia@example.com")
    expect(response.body).to include("registrado por ana@example.com")
  end
end
