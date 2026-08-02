require "rails_helper"
require "pbt"

RSpec.describe GroupBalanceCalculator do
  describe ".call" do
    it "retorna um hash vazio para um grupo sem memberships" do
      group = create(:group)

      expect(described_class.call(group)).to eq({})
    end

    it "inclui memberships sem fatos financeiros com saldo zero" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      create(:membership, group:, user: ana, position: 0)
      create(:membership, group:, user: bruno, position: 1)

      expect(described_class.call(group)).to eq(
        ana.id => 0,
        bruno.id => 0
      )
    end

    it "calcula o exemplo de uma despesa entre Ana, Bruno e Carla" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      [ ana, bruno, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 3_000, bruno => 3_000, carla => 3_000 })

      expect(described_class.call(group)).to eq(
        ana.id => 6_000,
        bruno.id => -3_000,
        carla.id => -3_000
      )
    end

    it "agrega despesas de múltiplos pagadores" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      [ ana, bruno, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000, carla => 3_000 })
      expense_with_shares(group:, payer: bruno, shares: { ana => 500, bruno => 500, carla => 2_000 })

      expect(described_class.call(group)).to eq(
        ana.id => 4_500,
        bruno.id => 500,
        carla.id => -5_000
      )
    end

    it "mantém no mapa participante fora de uma despesa" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      [ ana, bruno, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })

      expect(described_class.call(group)).to eq(
        ana.id => 2_000,
        bruno.id => -2_000,
        carla.id => 0
      )
    end

    it "mantém membership inativa com histórico no cálculo" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      create(:membership, group:, user: ana, position: 0)
      create(:membership, group:, user: bruno, status: :inactive, position: 1)
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })

      expect(described_class.call(group)).to eq(
        ana.id => 2_000,
        bruno.id => -2_000
      )
    end

    it "ignora despesas anuladas" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })
      voided_expense = expense_with_shares(group:, payer: bruno, shares: { ana => 1_000, bruno => 2_000 })
      voided_expense.update!(voided_by_user: ana, voided_at: Time.current, void_reason: "Duplicada")

      expect(described_class.call(group)).to eq(
        ana.id => 2_000,
        bruno.id => -2_000
      )
    end

    it "não persiste saldos nem altera a versão financeira" do
      group = create(:group, financial_state_version: 7)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })

      expect { described_class.call(group) }.not_to change { group.reload.financial_state_version }
    end

    it "aplica pagamento confirmado ao exemplo de Ana, Bruno e Carla" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      [ ana, bruno, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 3_000, bruno => 3_000, carla => 3_000 })
      create(:payment, :confirmed, group:, from_user: bruno, to_user: ana, amount_cents: 2_000)

      expect(described_class.call(group)).to eq(
        ana.id => 4_000,
        bruno.id => -1_000,
        carla.id => -3_000
      )
    end

    it "aproxima origem e destino de zero quando o pagamento é confirmado" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })
      create(:payment, :confirmed, group:, from_user: bruno, to_user: ana, amount_cents: 1_500)

      expect(described_class.call(group)).to eq(
        ana.id => 500,
        bruno.id => -500
      )
    end

    it "combina despesas e pagamentos confirmados" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      [ ana, bruno, carla ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000, carla => 3_000 })
      expense_with_shares(group:, payer: bruno, shares: { ana => 500, bruno => 500, carla => 2_000 })
      create(:payment, :confirmed, group:, from_user: carla, to_user: ana, amount_cents: 2_000)

      expect(described_class.call(group)).to eq(
        ana.id => 2_500,
        bruno.id => 500,
        carla.id => -3_000
      )
    end

    it "ignora pagamentos reported e cancelled" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })
      create(:payment, group:, from_user: bruno, to_user: ana, amount_cents: 1_000)
      create(:payment, :cancelled, group:, from_user: bruno, to_user: ana, amount_cents: 500)

      expect(described_class.call(group)).to eq(
        ana.id => 2_000,
        bruno.id => -2_000
      )
    end

    it "reporta e expõe ledger desequilibrado sem devolver resultado parcial" do
      group = create(:group, financial_state_version: 12)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 99, position: 0)
      reports = []
      subscriber = Object.new
      subscriber.define_singleton_method(:report) do |error, **attributes|
        reports << { error:, **attributes }
      end
      Rails.error.subscribe(subscriber)

      expect { described_class.call(group) }.to raise_error(GroupBalanceCalculator::UnbalancedLedger)
      expect(reports).to contain_exactly(
        include(
          error: an_instance_of(GroupBalanceCalculator::UnbalancedLedger),
          context: { group_id: group.id, financial_state_version: 12 }
        )
      )
    ensure
      Rails.error.unsubscribe(subscriber) if subscriber
    end

    it "detecta desequilíbrio de fatos sem membership no grupo" do
      group = create(:group)
      member = create(:user)
      outsider = create(:user)
      create(:membership, group:, user: member, position: 0)
      expense = create(:expense, group:, paid_by_user: outsider, created_by_user: outsider, amount_cents: 100)
      create(:expense_share, expense:, user: outsider, amount_owed_cents: 99, position: 0)

      expect { described_class.call(group) }.to raise_error(GroupBalanceCalculator::UnbalancedLedger)
    end

    it "reporta a versão financeira do mesmo snapshot do ledger" do
      group = create(:group, financial_state_version: 12)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense = create(:expense, group:, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
      create(:expense_share, expense:, user: bruno, amount_owed_cents: 99, position: 0)
      Group.where(id: group.id).update_all(financial_state_version: 13)
      reports = []
      subscriber = Object.new
      subscriber.define_singleton_method(:report) do |error, **attributes|
        reports << { error:, **attributes }
      end
      Rails.error.subscribe(subscriber)

      expect { described_class.call(group) }.to raise_error(GroupBalanceCalculator::UnbalancedLedger)
      expect(reports).to contain_exactly(
        include(context: { group_id: group.id, financial_state_version: 13 })
      )
    ensure
      Rails.error.unsubscribe(subscriber) if subscriber
    end

    it "ordena o hash por position e user_id" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      carla = create(:user)
      create(:membership, group:, user: carla, position: 2)
      create(:membership, group:, user: ana, position: 0)
      create(:membership, group:, user: bruno, position: 1)

      expect(described_class.call(group).keys).to eq([ ana.id, bruno.id, carla.id ])
    end

    it "retorna o mesmo mapa em chamadas repetidas e somente valores Integer" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })

      first = described_class.call(group)

      expect(described_class.call(group)).to eq(first)
      expect(first.values).to all(be_a(Integer))
    end

    it "converte agregados acima de bigint do PostgreSQL diretamente para Integer" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      maximum_bigint = 9_223_372_036_854_775_807
      2.times { expense_with_shares(group:, payer: ana, shares: { bruno => maximum_bigint }) }

      balances = described_class.call(group)

      expect(balances).to eq(
        ana.id => 18_446_744_073_709_551_614,
        bruno.id => -18_446_744_073_709_551_614
      )
      expect(balances.values).to all(be_a(Integer))
    end

    it "executa exatamente uma consulta nomeada para ler o ledger" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        payload = event.payload
        queries << payload.fetch(:name) unless payload[:cached] || payload[:name] == "SCHEMA"
      end

      described_class.call(group)

      expect(queries).to eq([ "GroupBalanceCalculator" ])
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    it "preserva as propriedades em 50 históricos persistidos válidos" do
      seed = Integer(ENV.fetch("PBT_SEED", "280726"))
      RSpec.configuration.reporter.message(
        "PBT seed: #{seed}; execuções: 50; worker: none; shrinking: habilitado"
      )

      Pbt.assert(num_runs: 50, worker: :none, seed:) do
        Pbt.property(Pbt.integer(min: 1, max: 1_000_000)) do |history_seed|
          group, ordered_user_ids = persisted_history(Random.new(history_seed))
          first = described_class.call(group)

          verify_balance_properties!(first, ordered_user_ids:)
          raise "o cálculo não é reproduzível" unless described_class.call(group) == first

          from_user_id, to_user_id = ordered_user_ids.first(2)
          amount_cents = Random.new(history_seed).rand(1..1_000)
          create(:payment, :confirmed, group:, from_user_id:, to_user_id:, amount_cents:)
          after_payment = described_class.call(group)
          expected_after_payment = first.merge(
            from_user_id => first.fetch(from_user_id) + amount_cents,
            to_user_id => first.fetch(to_user_id) - amount_cents
          )

          raise "o pagamento confirmado não aplicou seus deltas" unless after_payment == expected_after_payment
        end
      end
    end

    it "faz a propriedade falhar quando o controle negativo omite o delta do pagador" do
      group = create(:group)
      ana = create(:user)
      bruno = create(:user)
      [ ana, bruno ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      expense = expense_with_shares(group:, payer: ana, shares: { ana => 1_000, bruno => 2_000 })
      balances = described_class.call(group)
      missing_payer_delta = balances.merge(ana.id => balances.fetch(ana.id) - expense.amount_cents)

      expect do
        Pbt.assert(num_runs: 1, worker: :none, seed: 28_072_026) do
          Pbt.property(Pbt.integer(min: 1, max: 1)) do
            verify_balance_properties!(missing_payer_delta, ordered_user_ids: [ ana.id, bruno.id ])
          end
        end
      end.to raise_error(Pbt::PropertyFailure, /o ledger não conserva valor/)
    end
  end

  def expense_with_shares(group:, payer:, shares:)
    expense = create(
      :expense,
      group:,
      paid_by_user: payer,
      created_by_user: payer,
      amount_cents: shares.values.sum
    )
    shares.each_with_index do |(user, amount_owed_cents), position|
      create(:expense_share, expense:, user:, amount_owed_cents:, position:)
    end
    expense
  end

  def persisted_history(random)
    group = create(:group)
    users = Array.new(random.rand(2..4)) { create(:user) }
    users.each_with_index do |user, position|
      status = position < 2 || random.rand(2).zero? ? :active : :inactive
      create(:membership, group:, user:, position:, status:)
    end

    random.rand(1..3).times do
      payer = users.sample(random:)
      amounts = positive_shares(users, random)
      expense = expense_with_shares(group:, payer:, shares: amounts)
      expense.update!(voided_by_user: users.first, voided_at: Time.current, void_reason: "Teste") if random.rand(3).zero?
    end

    active_users = users.first(2)
    [ :reported, :confirmed, :cancelled ].each do |status|
      from_user, to_user = active_users.shuffle(random:)
      create_payment_with_status(group:, from_user:, to_user:, amount_cents: random.rand(1..1_000), status:)
    end

    [ group, users.map(&:id) ]
  end

  def positive_shares(users, random)
    total = random.rand(users.length..2_000)
    remaining = total
    users.each_with_index.to_h do |user, index|
      amount = index == users.length - 1 ? remaining : random.rand(1..(remaining - (users.length - index - 1)))
      remaining -= amount
      [ user, amount ]
    end
  end

  def create_payment_with_status(group:, from_user:, to_user:, amount_cents:, status:)
    traits = { confirmed: :confirmed, cancelled: :cancelled }
    traits.fetch(status, nil).then do |trait|
      trait ? create(:payment, trait, group:, from_user:, to_user:, amount_cents:) : create(:payment, group:, from_user:, to_user:, amount_cents:)
    end
  end

  def verify_balance_properties!(balances, ordered_user_ids:)
    raise "o mapa não inclui todas as memberships" unless balances.keys == ordered_user_ids
    raise "o ledger contém valor sem Integer" unless balances.values.all?(Integer)
    raise "o ledger não conserva valor" unless balances.values.sum.zero?
  end
end
