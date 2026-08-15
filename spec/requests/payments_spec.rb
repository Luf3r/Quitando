require "rails_helper"

RSpec.describe "Payments" do
  it "rejeita group_id malformado na confirmação antes de consultar tabelas financeiras" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    payment = create(:payment, group:, from_user: debtor, to_user: owner, reported_by_user: debtor, status: :reported)

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    queries = sql_queries_for("groups", "expenses", "expense_shares", "payments", "financial_command_receipts") do
      post "/groups/nao-e-um-uuid/payments/#{payment.id}/confirm", params: { payment: { idempotency_key: SecureRandom.uuid } }
    end

    expect(response).to have_http_status(:not_found)
    expect(queries).to be_empty
    expect(payment.reload).to be_reported
  end

  it "rejeita group_id malformado no cancelamento antes de consultar tabelas financeiras" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    payment = create(:payment, group:, from_user: debtor, to_user: owner, reported_by_user: debtor, status: :reported)

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    queries = sql_queries_for("groups", "expenses", "expense_shares", "payments", "financial_command_receipts") do
      post "/groups/nao-e-um-uuid/payments/#{payment.id}/cancel", params: { payment: { reason: "Transferência não enviada", idempotency_key: SecureRandom.uuid } }
    end

    expect(response).to have_http_status(:not_found)
    expect(queries).to be_empty
    expect(payment.reload).to be_reported
  end

  it "rejeita ID de pagamento malformado antes de consultar o grupo ou pagamentos" do
    owner = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")

    post user_session_path, params: { user: { email: owner.email, password: owner.password } }
    queries = sql_queries_for("groups", "payments") do
      get "/groups/#{group.id}/payments/nao-e-um-uuid"
    end

    expect(response).to have_http_status(:not_found)
    expect(queries).to be_empty
  end

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

  it "devolve 409, mantém os valores submetidos e atualiza a versão do report obsoleto" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id ] })

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    idempotency_key = SecureRandom.uuid
    post "/groups/#{group.id}/payments", params: { payment: { from_user_id: debtor.id, to_user_id: owner.id, amount_text: "5,00", expected_financial_state_version: group.reload.financial_state_version - 1, idempotency_key: } }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Plano líquido")
    expect(response.body).to include("Pagamento não registrado")
    expect(response.body).to include("5,00")
    expect(response.body).not_to include(idempotency_key)
    expect(response.body).not_to include("value=\"5,00\"")
    expect(response.body).not_to include("value=\"#{idempotency_key}\"")
    expect(response.body).to include("value=\"#{group.reload.financial_state_version}\"")
    expect(Payment.where(group:)).to be_empty
  end

  it "devolve 409 com a declaração submetida quando o plano atual não contém mais sua transferência" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "20,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id ] })
    submitted_version = group.reload.financial_state_version
    idempotency_key = SecureRandom.uuid

    ExpenseCreator.call(group_id: group.id, created_by_user_id: debtor.id, paid_by_user_id: debtor.id, description: "Jantar", occurred_on: Date.new(2026, 8, 15), amount_text: "40,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id ] })

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    post "/groups/#{group.id}/payments", params: { payment: { from_user_id: debtor.id, to_user_id: owner.id, amount_text: "5,00", expected_financial_state_version: submitted_version, idempotency_key: } }

    expect(response).to have_http_status(:conflict)
    conflict = Nokogiri::HTML(response.body).at_css("#conflito-pagamento")
    expect(conflict.text).to include("Pagamento não registrado")
    expect(conflict.text).to include(debtor.email)
    expect(conflict.text).to include(owner.email)
    expect(conflict.text).to include("5,00")
    expect(conflict.text).not_to include(idempotency_key)
    expect(conflict.text).not_to include(debtor.id)
    expect(conflict.text).not_to include(owner.id)
    expect(response.body).not_to include("Reportar pagamento")
    expect(Payment.where(group:)).to be_empty
  end

  it "mantém o formulário do plano substituído com valores próprios, não os do report obsoleto" do
    owner = create(:user, email: "ana@example.com")
    debtor = create(:user, email: "bia@example.com")
    peer = create(:user, email: "cai@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    create(:membership, group:, user: peer, position: 2)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 14), amount_text: "30,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id, peer.id ] })
    submitted_version = group.reload.financial_state_version
    submitted_idempotency_key = SecureRandom.uuid

    ExpenseCreator.call(group_id: group.id, created_by_user_id: peer.id, paid_by_user_id: peer.id, description: "Jantar", occurred_on: Date.new(2026, 8, 15), amount_text: "60,00", split: { type: :equal, participant_user_ids: [ owner.id, debtor.id, peer.id ] })

    post user_session_path, params: { user: { email: debtor.email, password: debtor.password } }
    post "/groups/#{group.id}/payments", params: { payment: { from_user_id: debtor.id, to_user_id: owner.id, amount_text: "5,00", expected_financial_state_version: submitted_version, idempotency_key: submitted_idempotency_key } }

    expect(response).to have_http_status(:conflict)
    document = Nokogiri::HTML(response.body)
    payment_form = document.at_css("form[action='/groups/#{group.id}/payments']")

    expect(payment_form.at_css("input[name='payment[from_user_id]']")["value"]).to eq(debtor.id)
    expect(payment_form.at_css("input[name='payment[to_user_id]']")["value"]).to eq(peer.id)
    expect(payment_form.at_css("input[name='payment[amount_text]']")["value"]).to eq("30,00")
    expect(payment_form.at_css("input[name='payment[expected_financial_state_version]']")["value"]).to eq(group.reload.financial_state_version.to_s)
    expect(payment_form.at_css("input[name='payment[expected_financial_state_version]']")["value"]).not_to eq(submitted_version.to_s)
    expect(payment_form.at_css("input[name='payment[idempotency_key]']")["value"]).not_to eq(submitted_idempotency_key)
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
