require "rails_helper"

RSpec.describe "Payments" do
  it "mostra um formulário de report no plano líquido" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id ] })

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    get "/groups/#{group.id}"

    expect(response.body).to include("Reportar pagamento")
  end

  it "permite à origem reportar valor parcial da sugestão atual por POST" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id ] })

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    expect {
      post "/groups/#{group.id}/payments", params: { payment: { from_user_id: debtor.id, to_user_id: owner.id, amount_text: "5,00", expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid } }
    }.to change(Payment, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(Payment.last).to have_attributes(status: "reported", amount_cents: 500, from_user_id: debtor.id, to_user_id: owner.id)
  end

  it "devolve 409 e o plano atual quando a versão do report está obsoleta" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id ] })

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    post "/groups/#{group.id}/payments", params: { payment: { from_user_id: debtor.id, to_user_id: owner.id, amount_text: "5,00", expected_financial_state_version: group.reload.financial_state_version - 1, idempotency_key: SecureRandom.uuid } }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Plano líquido")
    expect(Payment.where(group:)).to be_empty
  end

  it "permite ao destino confirmar um pagamento reportado" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    payment = create(:payment, group:, from_user: debtor, to_user: owner, reported_by_user: debtor, status: :reported)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    post "/groups/#{group.id}/payments/#{payment.id}/confirm", params: { payment: { idempotency_key: SecureRandom.uuid } }

    expect(response).to have_http_status(:see_other)
    expect(payment.reload).to be_confirmed
    expect(payment.confirmed_by_user_id).to eq(owner.id)
  end

  it "permite à origem cancelar um pagamento reportado" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    payment = create(:payment, group:, from_user: debtor, to_user: owner, reported_by_user: debtor, status: :reported)

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    post "/groups/#{group.id}/payments/#{payment.id}/cancel", params: { payment: { reason: "Transferência não enviada", idempotency_key: SecureRandom.uuid } }

    expect(response).to have_http_status(:see_other)
    expect(payment.reload).to be_cancelled
    expect(payment.cancelled_by_user_id).to eq(debtor.id)
  end
end
