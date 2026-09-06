require "rails_helper"

RSpec.describe "Preview de despesa" do
  it "retorna shares sem criar despesa e devolve 422 para entrada inválida" do
    ana = create(:user)
    bia = create(:user)
    outsider = create(:user)
    group = GroupCreator.call(owner_user_id: ana.id, name: "Casa")
    create(:membership, group:, user: bia, position: 1)
    post user_session_path, params: { user: { email: ana.email, password: ana.password } }

    expect {
      post group_expenses_preview_path(group), params: { expense: { description: "Mercado", occurred_on: Date.current.iso8601, amount_text: "10,00", split_type: "equal", paid_by_user_id: ana.id, participant_user_ids: [ ana.id, bia.id ] } }
    }.not_to change(Expense, :count)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revise a divisão")
    expect(response.body).to include(ana.name, bia.name)
    expect(response.body).not_to include(ana.email, bia.email)
    expect(response.body).to include("Confirmar despesa")
    expect(response.body).to include('name="expense[description]"')

    post group_expenses_preview_path(group), params: { expense: { description: "Mercado", occurred_on: Date.current.iso8601, amount_text: "10,00", split_type: "equal", paid_by_user_id: outsider.id, participant_user_ids: [ ana.id, bia.id ] } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("membership ativa obrigatória")
    expect(response.body).not_to include("Confirmar despesa")

    post group_expenses_preview_path(group), params: { expense: { description: "Mercado", occurred_on: Date.current.iso8601, amount_text: "10,00", split_type: "equal", paid_by_user_id: ana.id, participant_user_ids: [ ana.id ] } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("despesa deve gerar obrigação para não pagador")
    expect(response.body).not_to include("Confirmar despesa")

    post group_expenses_preview_path(group), params: { expense: { description: "Mercado", occurred_on: Date.current.iso8601, amount_text: "invalido", split_type: "equal", paid_by_user_id: ana.id, participant_user_ids: [ ana.id ] } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "revisa uma correção sem anular nem criar despesas" do
    ana = create(:user)
    bia = create(:user)
    group = GroupCreator.call(owner_user_id: ana.id, name: "Casa")
    create(:membership, group:, user: bia, position: 1)
    expense = ExpenseCreator.call(
      group_id: group.id, created_by_user_id: ana.id, paid_by_user_id: ana.id,
      description: "Mercado", occurred_on: Date.current, amount_text: "10,00",
      split: { type: :equal, participant_user_ids: [ ana.id, bia.id ] }
    )
    post user_session_path, params: { user: { email: ana.email, password: ana.password } }

    expect {
      post group_expense_correction_preview_path(group, expense), params: {
        correction: {
          reason: "Valor correto", description: "Mercado", amount_text: "12,00",
          paid_by_user_id: ana.id, split_type: "equal", participant_user_ids: [ ana.id, bia.id ],
          expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid
        }
      }
    }.not_to change(Expense, :count)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revise a correção")
    expect(response.body).to include(ana.name, bia.name)
    expect(response.body).not_to include(ana.email, bia.email)
    expect(response.body).to include("Confirmar correção")
    expect(expense.reload.voided_at).to be_nil
  end
end
