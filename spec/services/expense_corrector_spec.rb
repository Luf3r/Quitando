require "rails_helper"

RSpec.describe "ExpenseCorrector" do
  it "anula a original e cria uma substituta sem reescrever seus fatos financeiros" do
    group = create(:group)
    creator = create(:user)
    payer = create(:user)
    participant = create(:user)
    [ creator, payer, participant ].each_with_index do |user, position|
      create(:membership, group:, user:, role: user == creator ? :owner : :member, position:)
    end
    original = ExpenseCreator.call(
      group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: payer.id,
      description: "Mercado", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00",
      split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "4,00" }, { user_id: participant.id, amount_text: "6,00" } ] }
    )

    replacement = ExpenseCorrector.call(
      group_id: group.id, expense_id: original.id, actor_user_id: creator.id, reason: "Valor corrigido",
      paid_by_user_id: creator.id, description: "Mercado corrigido", occurred_on: original.occurred_on,
      amount_text: "12,00", split: { type: :exact, shares: [ { user_id: creator.id, amount_text: "3,00" }, { user_id: participant.id, amount_text: "9,00" } ] },
      expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid
    )

    expect(original.reload).to have_attributes(amount_cents: 1_000, paid_by_user_id: payer.id, created_by_user_id: creator.id, voided_by_user_id: creator.id, void_reason: "Valor corrigido")
    expect(original.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents)).to eq([ [ payer.id, 400 ], [ participant.id, 600 ] ])
    expect(replacement).to have_attributes(replaces_expense_id: original.id, amount_cents: 1_200, paid_by_user_id: creator.id, created_by_user_id: creator.id, description: "Mercado corrigido")
    expect(replacement.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents)).to eq([ [ creator.id, 300 ], [ participant.id, 900 ] ])
    expect(group.reload.financial_state_version).to eq(2)
  end

  it "corrige com divisão igual e distribui o residual pelo pagador" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.new(2026, 8, 6), amount_text: "2,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] })

    replacement = ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Total corrigido", paid_by_user_id: owner.id, description: "Jantar corrigido", occurred_on: original.occurred_on, amount_text: "10,01", split: { type: :equal, participant_user_ids: [ participant.id, owner.id ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)

    expect(replacement.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents)).to eq([ [ owner.id, 501 ], [ participant.id, 500 ] ])
  end

  it "rejeita uma correção que tente alterar a data da despesa" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })

    expect {
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Almoço corrigido", occurred_on: Date.new(2026, 8, 4), amount_text: "12,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "6,00" }, { user_id: participant.id, amount_text: "6,00" } ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
    }.to raise_error(ExpenseCorrector::InvalidExpense, "data da despesa é imutável")

    expect(original.reload).to have_attributes(voided_at: nil, occurred_on: Date.new(2026, 8, 3))
    expect(group.reload.financial_state_version).to eq(1)
    expect(Expense.where(replaces_expense_id: original.id)).to be_empty
  end

  it "rejeita identificadores malformados antes de acessar o grupo" do
    invalid_attributes = {
      group_id: 123,
      expense_id: "018f0b5b-2df3-7c64-8000-000000000001",
      actor_user_id: "018f0b5b-2df3-7c64-8000-000000000002",
      reason: "Valor corrigido",
      paid_by_user_id: "018f0b5b-2df3-7c64-8000-000000000003",
      description: "Almoço corrigido",
      occurred_on: Date.new(2026, 8, 3),
      amount_text: "12,00",
      split: { type: :equal, participant_user_ids: [ "018f0b5b-2df3-7c64-8000-000000000002", "018f0b5b-2df3-7c64-8000-000000000003" ] },
      expected_financial_state_version: 1,
      idempotency_key: SecureRandom.uuid
    }

    expect(Group).not_to receive(:lock)
    expect {
      ExpenseCorrector.call(**invalid_attributes)
    }.to raise_error(ExpenseCorrector::InvalidExpense, "identificadores inválidos")
  end

  it "rejeita grupo arquivado sem persistir efeitos da correção" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] })
    group.update!(archived_at: Time.current)

    expect {
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Almoço corrigido", occurred_on: original.occurred_on, amount_text: "12,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
    }.to raise_error(ExpenseCorrector::ArchivedGroup, "grupo arquivado")

    expect(original.reload).to have_attributes(voided_at: nil, voided_by_user_id: nil, void_reason: nil)
    expect(Expense.where(replaces_expense_id: original.id)).to be_empty
    expect(FinancialCommandReceipt.where(command_type: :expense_correct, expense_id: Expense.where(group_id: group.id))).to be_empty
    expect(group.reload.financial_state_version).to eq(1)
  end

  it "rejeita o creator que não é mais membro ativo sem alterar o histórico" do
    group = create(:group)
    creator = create(:user)
    participant = create(:user)
    creator_membership = create(:membership, group:, user: creator, role: :owner, position: 0)
    create(:membership, group:, user: participant, position: 1)
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: creator.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :equal, participant_user_ids: [ creator.id, participant.id ] })
    creator_membership.update!(status: :inactive)

    expect {
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: creator.id, reason: "Valor corrigido", paid_by_user_id: creator.id, description: "Almoço corrigido", occurred_on: original.occurred_on, amount_text: "12,00", split: { type: :equal, participant_user_ids: [ creator.id, participant.id ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
    }.to raise_error(ExpenseCorrector::Forbidden, "membership ativa obrigatória")

    expect(original.reload.voided_at).to be_nil
    expect(Expense.where(replaces_expense_id: original.id)).to be_empty
    expect(group.reload.financial_state_version).to eq(1)
  end

  it "reconhece como retry o split exato semanticamente equivalente" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
    key = SecureRandom.uuid
    arguments = { group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Almoço corrigido", occurred_on: original.occurred_on, amount_text: "12,00", expected_financial_state_version: 1, idempotency_key: key }

    replacement = ExpenseCorrector.call(**arguments, split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "6,00" }, { user_id: participant.id, amount_text: "6,00" } ] })
    retried = ExpenseCorrector.call(**arguments, split: { type: :exact, shares: [ { user_id: participant.id, amount_text: "6" }, { user_id: owner.id, amount_text: "6,00" } ] })

    expect(retried).to have_attributes(id: replacement.id)
    expect(Expense.where(replaces_expense_id: original.id).count).to eq(1)
    expect(group.reload.financial_state_version).to eq(2)
  end

  it "rejeita retry com a mesma chave e payload de correção divergente" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
    key = SecureRandom.uuid
    attributes = { group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, occurred_on: original.occurred_on, amount_text: "12,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "6,00" }, { user_id: participant.id, amount_text: "6,00" } ] }, expected_financial_state_version: 1, idempotency_key: key }
    replacement = ExpenseCorrector.call(**attributes, description: "Almoço corrigido")

    expect {
      ExpenseCorrector.call(**attributes, description: "Outro texto")
    }.to raise_error(ExpenseCorrector::IdempotencyConflict, "chave de idempotência reutilizada")

    expect(Expense.where(replaces_expense_id: original.id)).to contain_exactly(replacement)
    expect(group.reload.financial_state_version).to eq(2)
  end

  it "autoriza a despesa antes de resolver um recibo de retry" do
    group = create(:group)
    creator = create(:user)
    outsider = create(:user)
    participant = create(:user)
    [ creator, outsider, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == creator ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: creator.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :equal, participant_user_ids: [ creator.id, participant.id ] })
    original.update!(voided_at: Time.current, voided_by_user_id: creator.id, void_reason: "Valor corrigido")
    replacement = create(:expense, group:, created_by_user: creator, paid_by_user: creator, amount_cents: 1_200, description: "Almoço corrigido", occurred_on: original.occurred_on, replaces_expense: original)
    key = SecureRandom.uuid
    fingerprint = Digest::SHA256.hexdigest(JSON.generate([ "v1", "expense_correct", group.id, original.id, outsider.id, 2, "Outro motivo", creator.id, "Outra descrição", original.occurred_on.iso8601, 1_200, [ "equal", [ creator.id, participant.id ].sort ] ]))
    FinancialCommandReceipt.create!(expense: replacement, command_type: :expense_correct, idempotency_key: key, request_fingerprint: fingerprint)

    expect {
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: outsider.id, reason: "Outro motivo", paid_by_user_id: creator.id, description: "Outra descrição", occurred_on: original.occurred_on, amount_text: "12,00", split: { type: :equal, participant_user_ids: [ participant.id, creator.id ] }, expected_financial_state_version: 2, idempotency_key: key)
    }.to raise_error(ExpenseCorrector::Forbidden, "ator não autorizado")
  end

  it "rejeita uma chave já usada por um comando de pagamento" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Almoço", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
    payment = create(:payment)
    key = SecureRandom.uuid
    PaymentCommandReceipt.create!(payment:, command_type: :report, idempotency_key: key, request_fingerprint: "pagamento")

    expect {
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Almoço corrigido", occurred_on: original.occurred_on, amount_text: "12,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "6,00" }, { user_id: participant.id, amount_text: "6,00" } ] }, expected_financial_state_version: 1, idempotency_key: key)
    }.to raise_error(ExpenseCorrector::IdempotencyConflict, "chave de idempotência reutilizada")

    expect(original.reload.voided_at).to be_nil
    expect(group.reload.financial_state_version).to eq(1)
  end

  it "preserva pagamentos e recalcula saldo, projeção e plano pela substituta ativa" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, role: user == receiver ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })
    payment = PaymentReporter.call(group_id: group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "1,00", expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)
    payment_snapshot = payment.attributes

    replacement = ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: receiver.id, reason: "Total corrigido", paid_by_user_id: receiver.id, description: "Jantar corrigido", occurred_on: original.occurred_on, amount_text: "8,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }, expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)

    expect(payment.reload.attributes).to eq(payment_snapshot)
    expect(original.reload.voided_at).to be_present
    expect(replacement.reload.voided_at).to be_nil
    expect(GroupBalanceCalculator.call(group.reload)).to eq(receiver.id => 400, sender.id => -400)
    expect(ProjectedBalanceCalculator.call(GroupBalanceCalculator.call(group.reload), group.payments.reported)).to eq(receiver.id => 300, sender.id => -300)
    expect(SettlementPlanGenerator.call(group.reload)).to eq([ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 300) ])
    expect(group.reload.financial_state_version).to eq(3)
  end

  it "preserva pagamento confirmado e recalcula o saldo oficial pela substituta" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, role: user == receiver ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })
    payment = PaymentReporter.call(group_id: group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "1,00", expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)
    PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid)
    payment_snapshot = payment.reload.attributes

    ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: receiver.id, reason: "Total corrigido", paid_by_user_id: receiver.id, description: "Jantar corrigido", occurred_on: original.occurred_on, amount_text: "8,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] }, expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)

    expect(payment.reload.attributes).to eq(payment_snapshot)
    expect(payment).to be_confirmed
    expect(GroupBalanceCalculator.call(group.reload)).to eq(receiver.id => 300, sender.id => -300)
    expect(SettlementPlanGenerator.call(group.reload)).to eq([ DebtSimplifier::Transfer.new(from_user_id: sender.id, to_user_id: receiver.id, amount_cents: 300) ])
    expect(group.reload.financial_state_version).to eq(4)
  end

  it "reverte substituta e anulação quando o recibo falha depois das escritas financeiras" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] })
    connection = ActiveRecord::Base.connection
    connection.execute("CREATE FUNCTION reject_expense_correction_receipt() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'receipt failure' USING ERRCODE = '23514'; END; $$")
    connection.execute("CREATE TRIGGER reject_expense_correction_receipt BEFORE INSERT ON financial_command_receipts FOR EACH ROW WHEN (NEW.command_type = 'expense_correct') EXECUTE FUNCTION reject_expense_correction_receipt()")

    expect {
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Jantar corrigido", occurred_on: original.occurred_on, amount_text: "12,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
    }.to raise_error(ActiveRecord::StatementInvalid, /receipt failure/)

    expect(original.reload.voided_at).to be_nil
    expect(Expense.where(replaces_expense_id: original.id)).to be_empty
    expect(FinancialCommandReceipt.where(command_type: :expense_correct)).to be_empty
    expect(group.reload.financial_state_version).to eq(1)
  ensure
    connection.execute("DROP TRIGGER IF EXISTS reject_expense_correction_receipt ON financial_command_receipts") if connection
    connection.execute("DROP FUNCTION IF EXISTS reject_expense_correction_receipt()") if connection
  end
end

RSpec.describe "ExpenseCorrector post-commit events", :non_transactional do
  self.use_transactional_tests = false

  it "publica a correção somente após o commit externo" do
    group = create(:group)
    actor = create(:user)
    participant = create(:user)
    create(:membership, group:, user: actor, role: :owner, position: 0)
    create(:membership, group:, user: participant, position: 1)
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: actor.id, paid_by_user_id: actor.id, description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] })
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.corrected") { |event| events << event.payload }

    replacement = nil
    Group.transaction do
      replacement = ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: actor.id, reason: "Valor correto", paid_by_user_id: actor.id, description: "Mercado corrigido", occurred_on: original.occurred_on, amount_text: "3,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "2,00" } ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
      expect(events).to be_empty
    end

    expect(events).to contain_exactly(original_expense_id: original.id, replacement_expense_id: replacement.id, group_id: group.id, actor_user_id: actor.id, financial_state_version: 2)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: Expense.where(group_id: group.id).select(:id))) if group
    delete_expense_history_for_cleanup!(Expense.where(group_id: group.id)) if group
    Membership.where(group_id: group.id).delete_all if group
    Group.where(id: group.id).delete_all if group
    User.where(id: [ actor, participant ].compact.map(&:id)).delete_all if defined?(actor)
  end

  it "não publica nem persiste a correção quando a transação externa sofre rollback" do
    group = create(:group)
    actor = create(:user)
    participant = create(:user)
    create(:membership, group:, user: actor, role: :owner, position: 0)
    create(:membership, group:, user: participant, position: 1)
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: actor.id, paid_by_user_id: actor.id, description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] })
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.corrected") { |event| events << event.payload }

    Group.transaction do
      ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: actor.id, reason: "Valor correto", paid_by_user_id: actor.id, description: "Mercado corrigido", occurred_on: original.occurred_on, amount_text: "3,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "2,00" } ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
      raise ActiveRecord::Rollback
    end

    expect(events).to be_empty
    expect(original.reload.voided_at).to be_nil
    expect(Expense.where(replaces_expense_id: original.id)).to be_empty
    expect(group.reload.financial_state_version).to eq(1)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: Expense.where(group_id: group.id).select(:id))) if group
    delete_expense_history_for_cleanup!(Expense.where(group_id: group.id)) if group
    Membership.where(group_id: group.id).delete_all if group
    Group.where(id: group.id).delete_all if group
    User.where(id: [ actor, participant ].compact.map(&:id)).delete_all if defined?(actor)
  end

  it "também destaca criação em nome de outro pagador após o commit" do
    group = create(:group)
    actor = create(:user)
    payer = create(:user)
    participant = create(:user)
    [ actor, payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == actor ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: actor.id, paid_by_user_id: actor.id, description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] })
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| events << event.payload }

    replacement = ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: actor.id, reason: "Pagador correto", paid_by_user_id: payer.id, description: "Mercado corrigido", occurred_on: original.occurred_on, amount_text: "3,00", split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "2,00" } ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)

    expect(events).to contain_exactly(expense_id: replacement.id, group_id: group.id, recipient_user_id: payer.id, created_by_user_id: actor.id)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: Expense.where(group_id: group.id).select(:id))) if group
    delete_expense_history_for_cleanup!(Expense.where(group_id: group.id)) if group
    Membership.where(group_id: group.id).delete_all if group
    Group.where(id: group.id).delete_all if group
    User.where(id: [ actor, payer, participant ].compact.map(&:id)).delete_all if defined?(actor)
  end

  it "preserva a correção commitada quando um consumidor pós-commit falha" do
    group = create(:group)
    actor = create(:user)
    participant = create(:user)
    [ actor, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == actor ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: actor.id, paid_by_user_id: actor.id, description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] })
    reports = []
    error_subscriber = Object.new
    error_subscriber.define_singleton_method(:report) { |error, handled:, severity:, context:, source:| reports << { error:, handled:, severity:, context:, source: } }
    Rails.error.subscribe(error_subscriber)
    observed_state = nil
    event_subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.corrected") do |event|
      observed_state = Expense.find_by!(id: event.payload.fetch(:replacement_expense_id)).voided_at
      raise "consumer failure"
    end

    replacement = ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: actor.id, reason: "Valor correto", paid_by_user_id: actor.id, description: "Mercado corrigido", occurred_on: original.occurred_on, amount_text: "3,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "2,00" } ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)

    expect(replacement.reload.voided_at).to be_nil
    expect(original.reload.voided_at).to be_present
    expect(group.reload.financial_state_version).to eq(2)
    expect(observed_state).to be_nil
    expect(reports).to contain_exactly(include(error: have_attributes(message: "consumer failure"), handled: true, severity: :error, context: include(original_expense_id: original.id, replacement_expense_id: replacement.id), source: "quitando.expense.corrected"))
  ensure
    ActiveSupport::Notifications.unsubscribe(event_subscriber) if event_subscriber
    Rails.error.unsubscribe(error_subscriber) if error_subscriber
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: Expense.where(group_id: group.id).select(:id))) if group
    delete_expense_history_for_cleanup!(Expense.where(group_id: group.id)) if group
    Membership.where(group_id: group.id).delete_all if group
    Group.where(id: group.id).delete_all if group
    User.where(id: [ actor, participant ].compact.map(&:id)).delete_all if defined?(actor)
  end

  it "publica o destaque ao novo pagador mesmo se um consumidor da correção falhar" do
    group = create(:group)
    actor = create(:user)
    payer = create(:user)
    participant = create(:user)
    [ actor, payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == actor ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: actor.id, paid_by_user_id: actor.id, description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00", split: { type: :exact, shares: [ { user_id: actor.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] })
    corrected_subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.corrected") { raise "consumer failure" }
    third_party_events = []
    third_party_subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| third_party_events << event.payload }

    replacement = ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: actor.id, reason: "Pagador correto", paid_by_user_id: payer.id, description: "Mercado corrigido", occurred_on: original.occurred_on, amount_text: "3,00", split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "2,00" } ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)

    expect(third_party_events).to contain_exactly(expense_id: replacement.id, group_id: group.id, recipient_user_id: payer.id, created_by_user_id: actor.id)
  ensure
    ActiveSupport::Notifications.unsubscribe(corrected_subscriber) if corrected_subscriber
    ActiveSupport::Notifications.unsubscribe(third_party_subscriber) if third_party_subscriber
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: Expense.where(group_id: group.id).select(:id))) if group
    delete_expense_history_for_cleanup!(Expense.where(group_id: group.id)) if group
    Membership.where(group_id: group.id).delete_all if group
    Group.where(id: group.id).delete_all if group
    User.where(id: [ actor, payer, participant ].compact.map(&:id)).delete_all if defined?(actor)
  end
end
