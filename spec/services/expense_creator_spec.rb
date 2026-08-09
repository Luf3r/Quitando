require "rails_helper"

RSpec.describe ExpenseCreator do
  describe ".call" do
    it "cria despesa e shares iguais de forma auditável e incrementa a versão uma vez" do
      group = create(:group)
      creator = create(:user)
      payer = create(:user)
      participant = create(:user)
      create(:membership, group:, user: creator, role: :owner, position: 0)
      create(:membership, group:, user: payer, position: 1)
      create(:membership, group:, user: participant, position: 2)

      expense = described_class.call(
        group_id: group.id,
        created_by_user_id: creator.id,
        paid_by_user_id: payer.id,
        description: "Mercado",
        occurred_on: Date.new(2026, 7, 27),
        amount_text: "10,01",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
      )

      expect(expense).to have_attributes(
        group_id: group.id,
        created_by_user_id: creator.id,
        paid_by_user_id: payer.id,
        amount_cents: 1_001,
        description: "Mercado",
        occurred_on: Date.new(2026, 7, 27)
      )
      expect(expense.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents, :position)).to eq(
        [ [ payer.id, 501, 0 ], [ participant.id, 500, 1 ] ]
      )
      expect(group.reload.financial_state_version).to eq(1)
    end

    it "cria divisão exata somente quando a soma coincide com a despesa" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      expense = described_class.call(
        group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
        description: "Jantar", occurred_on: Date.new(2026, 7, 27), amount_text: "10,00",
        split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "4,00" }, { user_id: participant.id, amount_text: "6,00" } ] }
      )

      expect(expense.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents)).to eq([ [ payer.id, 400 ], [ participant.id, 600 ] ])
    end

    it "persiste a divisão exata na ordem estável das memberships, independentemente do payload" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      create(:membership, group:, user: payer, position: 1)
      create(:membership, group:, user: participant, position: 0)

      expense = described_class.call(
        group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
        description: "Jantar", occurred_on: Date.new(2026, 7, 27), amount_text: "10,00",
        split: {
          type: :exact,
          shares: [
            { user_id: payer.id, amount_text: "4,00" },
            { user_id: participant.id, amount_text: "6,00" }
          ]
        }
      )

      expect(expense.expense_shares.order(:position).pluck(:user_id, :amount_owed_cents, :position)).to eq(
        [ [ participant.id, 600, 0 ], [ payer.id, 400, 1 ] ]
      )
    end

    it "faz rollback integral quando a soma exata diverge" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Jantar", occurred_on: Date.new(2026, 7, 27), amount_text: "10,00",
          split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "4,00" }, { user_id: participant.id, amount_text: "5,00" } ] }
        )
      end.to raise_error(ExpenseCreator::InvalidExpense)

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "rejeita participantes duplicados nas divisões exata e igual" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Duplicada", occurred_on: Date.current, amount_text: "2,00",
          split: {
            type: :exact,
            shares: [
              { user_id: participant.id, amount_text: "1,00" },
              { user_id: participant.id, amount_text: "1,00" }
            ]
          }
        )
      end.to raise_error(ExpenseCreator::InvalidExpense, "shares duplicadas")

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Duplicada", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ participant.id, participant.id ] }
        )
      end.to raise_error(ExpenseCreator::InvalidExpense, "divisão inválida")

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "rejeita estruturas malformadas de divisão com erro de domínio e sem persistência" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      malformed_splits = [
        { type: :exact, shares: [ nil ] },
        { type: :exact, shares: [ { "user_id" => payer.id, "amount_text" => "2,00" } ] },
        { type: :exact, shares: [ { user_id: payer.id } ] },
        { type: :exact, shares: [ { user_id: payer.id, amount_text: "valor-inválido" } ] }
      ]

      malformed_splits.each do |malformed_split|
        expect do
          described_class.call(
            group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
            description: "Teste", occurred_on: Date.current, amount_text: "2,00", split: malformed_split
          )
        end.to raise_error(ExpenseCreator::InvalidExpense, "divisão inválida")
      end

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "rejeita identificadores malformados do comando antes de consultar o banco" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      valid_attributes = {
        group_id: group.id,
        created_by_user_id: payer.id,
        paid_by_user_id: payer.id,
        description: "Teste",
        occurred_on: Date.current,
        amount_text: "2,00",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
      }

      invalid_identifiers = [
        "uuid-inválido",
        "018f0f3e-7b6c-4a10-8b2c-1234567890ab",
        "018f0f3e-7b6c-6a10-8b2c-1234567890ab",
        "018f0f3e-7b6c-7a10-0b2c-1234567890ab",
        "018F0F3E-7B6C-7A10-8B2C-1234567890AB"
      ]

      %i[group_id created_by_user_id paid_by_user_id].product(invalid_identifiers).each do |attribute, invalid_identifier|
        expect do
          described_class.call(**valid_attributes.merge(attribute => invalid_identifier))
        end.to raise_error(ExpenseCreator::InvalidExpense, "identificadores inválidos")
      end

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "rejeita IDs malformados em splits equal e exact antes de bloquear o grupo" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      attributes = {
        group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
        description: "Teste", occurred_on: Date.current, amount_text: "2,00"
      }

      [
        { type: :equal, participant_user_ids: [ payer.id, "uuid-inválido" ] },
        { type: :exact, shares: [ { user_id: payer.id, amount_text: "1,00" }, { user_id: "uuid-inválido", amount_text: "1,00" } ] }
      ].each do |split|
        expect(Group).not_to receive(:lock)

        expect {
          described_class.call(**attributes, split:)
        }.to raise_error(ExpenseCreator::InvalidExpense, "identificadores inválidos")
      end
    end

    it "rejeita divisão igual que produziria share zero com erro de domínio" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "0,01",
          split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
        )
      end.to raise_error(ExpenseCreator::InvalidExpense, "divisão inválida")

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "aceita o máximo bigint e rejeita o primeiro centavo acima sem persistência parcial" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      expense = described_class.call(
        group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
        description: "Limite", occurred_on: Date.current, amount_text: "92.233.720.368.547.758,07",
        split: {
          type: :exact,
          shares: [
            { user_id: payer.id, amount_text: "92.233.720.368.547.758,06" },
            { user_id: participant.id, amount_text: "0,01" }
          ]
        }
      )

      expect(expense.amount_cents).to eq(9_223_372_036_854_775_807)
      expect(expense.expense_shares.sum(:amount_owed_cents)).to eq(expense.amount_cents)

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Overflow", occurred_on: Date.current, amount_text: "92.233.720.368.547.758,08",
          split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
        )
      end.to raise_error(MoneyParser::InvalidAmount, "valor excede o limite de bigint")

      expect(group.expenses.count).to eq(1)
      expect(group.reload.financial_state_version).to eq(1)
    end

    it "reverte despesa e shares quando a versão financeira excederia bigint" do
      group = create(:group, financial_state_version: 9_223_372_036_854_775_807)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Overflow de versão", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
        )
      end.to raise_error(ActiveRecord::StatementInvalid)

      expect(group.expenses).to be_empty
      expect(ExpenseShare.joins(:expense).where(expenses: { group_id: group.id })).to be_empty
      expect(group.reload.financial_state_version).to eq(9_223_372_036_854_775_807)
    end

    it "rejeita despesa cuja única share pertence ao pagador" do
      group = create(:group)
      payer = create(:user)
      create(:membership, group:, user: payer, position: 0)

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Sem obrigação", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "2,00" } ] }
        )
      end.to raise_error(ExpenseCreator::InvalidExpense, "despesa deve gerar obrigação para não pagador")

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "revalida creator e pagador ativos no grupo independentemente dos participantes" do
      group = create(:group)
      active_creator = create(:user)
      active_payer = create(:user)
      participant = create(:user)
      inactive_creator = create(:user)
      outside_payer = create(:user)
      create(:membership, group:, user: active_creator, position: 0)
      create(:membership, group:, user: active_payer, position: 1)
      create(:membership, group:, user: participant, position: 2)
      create(:membership, group:, user: inactive_creator, status: :inactive, position: 3)
      create(:membership, group: create(:group), user: outside_payer, position: 0)

      invalid_actors = [
        [ inactive_creator.id, active_payer.id ],
        [ active_creator.id, outside_payer.id ]
      ]
      invalid_actors.each do |creator_id, payer_id|
        expect do
          described_class.call(
            group_id: group.id, created_by_user_id: creator_id, paid_by_user_id: payer_id,
            description: "Atores inválidos", occurred_on: Date.current, amount_text: "2,00",
            split: { type: :equal, participant_user_ids: [ active_payer.id, participant.id ] }
          )
        end.to raise_error(ExpenseCreator::InvalidExpense, "membership ativa obrigatória")
      end

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "rejeita grupo arquivado e memberships inativas ou externas sem persistir" do
      group = create(:group, archived_at: Time.current)
      payer = create(:user)
      participant = create(:user)
      create(:membership, group:, user: payer, position: 0)
      create(:membership, group:, user: participant, position: 1)

      expect do
        described_class.call(group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] })
      end.to raise_error(ExpenseCreator::InvalidExpense, "grupo arquivado")
      expect(group.expenses).to be_empty

      active_group = create(:group)
      inactive = create(:user)
      outside = create(:user)
      create(:membership, group: active_group, user: payer, position: 0)
      create(:membership, group: active_group, user: inactive, status: :inactive, position: 1)
      create(:membership, group: create(:group), user: outside, position: 0)

      [ inactive.id, outside.id ].each do |participant_id|
        expect do
          described_class.call(group_id: active_group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
            description: "Teste", occurred_on: Date.current, amount_text: "2,00",
            split: { type: :equal, participant_user_ids: [ payer.id, participant_id ] })
        end.to raise_error(ExpenseCreator::InvalidExpense, "membership ativa obrigatória")
      end
      expect(active_group.expenses).to be_empty
    end

    it "faz rollback integral quando o PostgreSQL recusa uma share" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      connection = ApplicationRecord.connection
      constraint = "expense_shares_reject_test"
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| events << event.payload }
      connection.add_check_constraint(:expense_shares, "amount_owed_cents <> 100", name: constraint)

      expect do
        described_class.call(group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] })
      end.to raise_error(ActiveRecord::StatementInvalid)

      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
      expect(events).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      connection.remove_check_constraint(:expense_shares, name: constraint) if connection.check_constraints(:expense_shares).any? { |check| check.name == constraint }
    end

    it "publica evento somente após commit quando creator e pagador diferem" do
      group = create(:group)
      creator = create(:user)
      payer = create(:user)
      create(:membership, group:, user: creator, position: 0)
      create(:membership, group:, user: payer, position: 1)
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| events << event.payload }

      expense = described_class.call(group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: payer.id,
        description: "Teste", occurred_on: Date.current, amount_text: "2,00",
        split: { type: :equal, participant_user_ids: [ creator.id, payer.id ] })

      expect(events).to eq(
        [
          {
            expense_id: expense.id,
            group_id: group.id,
            recipient_user_id: payer.id,
            created_by_user_id: creator.id
          }
        ]
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    it "mantém o sucesso já commitado e reporta operacionalmente quando um consumidor do evento falha" do
      group = create(:group)
      creator = create(:user)
      payer = create(:user)
      [ creator, payer ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      reports = []
      error_subscriber = Object.new
      error_subscriber.define_singleton_method(:report) do |error, handled:, severity:, context:, source:|
        reports << { error:, handled:, severity:, context:, source: }
      end
      Rails.error.subscribe(error_subscriber)
      event_subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") do
        raise "consumidor indisponível"
      end

      expect do
        described_class.call(
          group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ creator.id, payer.id ] }
        )
      end.to change(group.expenses, :count).by(1)
        .and change { group.reload.financial_state_version }.by(1)

      expect(reports.length).to eq(1)
      expect(reports.first).to include(
        handled: true,
        severity: :error,
        source: "quitando.expense.created_by_third_party"
      )
      expect(reports.first.fetch(:error)).to have_attributes(message: "consumidor indisponível")
      expect(reports.first.fetch(:context)).to include(group_id: group.id, created_by_user_id: creator.id)
    ensure
      ActiveSupport::Notifications.unsubscribe(event_subscriber) if event_subscriber
      Rails.error.unsubscribe(error_subscriber) if error_subscriber
    end

    it "não publica antes do commit externo nem depois de rollback externo" do
      group = create(:group)
      creator = create(:user)
      payer = create(:user)
      [ creator, payer ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| events << event.payload }

      ActiveRecord::Base.transaction do
        described_class.call(group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ creator.id, payer.id ] })
        expect(events).to be_empty
        raise ActiveRecord::Rollback
      end

      expect(events).to be_empty
      expect(group.expenses).to be_empty
      expect(group.reload.financial_state_version).to eq(0)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    it "publica exatamente uma vez somente depois do commit externo bem-sucedido" do
      group = create(:group)
      creator = create(:user)
      payer = create(:user)
      [ creator, payer ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| events << event.payload }

      expense = nil
      ActiveRecord::Base.transaction do
        expense = described_class.call(
          group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ creator.id, payer.id ] }
        )
        expect(events).to be_empty
      end

      expect(events).to eq(
        [
          {
            expense_id: expense.id,
            group_id: group.id,
            recipient_user_id: payer.id,
            created_by_user_id: creator.id
          }
        ]
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    it "não publica evento para creator igual ao pagador ou quando a validação falha" do
      group = create(:group)
      payer = create(:user)
      participant = create(:user)
      [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("quitando.expense.created_by_third_party") { |event| events << event.payload }

      described_class.call(group_id: group.id, created_by_user_id: payer.id, paid_by_user_id: payer.id,
        description: "Teste", occurred_on: Date.current, amount_text: "2,00",
        split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] })

      expect do
        described_class.call(group_id: group.id, created_by_user_id: participant.id, paid_by_user_id: payer.id,
          description: "Teste", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :exact, shares: [ { user_id: payer.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "0,50" } ] })
      end.to raise_error(ExpenseCreator::InvalidExpense)

      expect(events).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
