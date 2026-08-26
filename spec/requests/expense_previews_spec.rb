require "rails_helper"

RSpec.describe "Preview de despesa" do
  it "retorna shares sem criar despesa e devolve 422 para entrada inválida" do
    ana = create(:user)
    group = GroupCreator.call(owner_user_id: ana.id, name: "Casa")
    post user_session_path, params: { user: { email: ana.email, password: ana.password } }

    expect {
      post group_expenses_preview_path(group), params: { expense: { amount_text: "10,00", split_type: "equal", paid_by_user_id: ana.id, participant_user_ids: [ ana.id ] } }
    }.not_to change(Expense, :count)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revise a divisão")

    post group_expenses_preview_path(group), params: { expense: { amount_text: "invalido", split_type: "equal", paid_by_user_id: ana.id, participant_user_ids: [ ana.id ] } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
