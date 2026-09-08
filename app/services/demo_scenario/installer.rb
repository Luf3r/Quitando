class DemoScenario::Installer
  SCENARIO_KEY = "canonical-v2"
  SCENARIO_VERSION = 2
  PUBLIC_ACCOUNTS = { ana: "ana@demo.quitando.test", bruno: "bruno@demo.quitando.test", carla: "carla@demo.quitando.test", diego: "diego@demo.quitando.test" }.freeze
  PUBLIC_NAMES = { ana: "Ana", bruno: "Bruno", carla: "Carla", diego: "Diego" }.freeze
  ScenarioConflict = Class.new(StandardError)

  # Declarative facts; all persistence below still goes through domain commands.
  MANIFEST = {
    serra: { name: "Viagem para a serra", owner: :ana, members: %i[bruno carla diego] },
    apartamento: { name: "Contas do apartamento", owner: :bruno, members: %i[ana carla diego] },
    configuracao: { name: "Configuração da república", owner: :ana, members: %i[bruno carla diego] },
    casa: { name: "Casa de praia quitada", owner: :ana, members: %i[bruno carla diego] },
    proxima: { name: "Próxima viagem", owner: :ana, members: [] },
    churrasco: { name: "Churrasco arquivado", owner: :carla, members: %i[ana] }
  }.freeze
  private_constant :MANIFEST

  def self.call(config: DemoScenario::Config.new) = new(config:).call

  def initialize(config:) = @config = config

  def call
    config.validate_installation!
    DemoScenario.transaction do
      DemoScenario::Lock.acquire!
      existing = DemoScenario.first
      return existing if canonical_marker?(existing)
      raise ScenarioConflict, "cenário demo incompatível; execute o reset integral autorizado" if existing

      install!
    end
  end

  private

  attr_reader :config

  def canonical_marker?(scenario) = scenario && scenario.key == SCENARIO_KEY && scenario.version == SCENARIO_VERSION

  def install!
    accounts = create_public_accounts!
    installed_at = Time.current
    install_serra!(accounts, installed_at:)
    install_configuracao!(accounts, installed_at:)
    install_apartamento!(accounts, installed_at:)
    install_proxima_viagem!(accounts)
    install_casa_de_praia!(accounts, installed_at:)
    install_churrasco!(accounts, installed_at:)
    validate_balances!
    DemoScenario.create!(key: SCENARIO_KEY, version: SCENARIO_VERSION, installed_at:, last_reset_at: installed_at)
  end

  def create_public_accounts!
    PUBLIC_ACCOUNTS.to_h do |key, email|
      user = User.create!(
        name: PUBLIC_NAMES.fetch(key),
        email:,
        password: config.public_password,
        password_confirmation: config.public_password,
        demo_account: true
      )
      [ key, user ]
    end
  end

  def install_serra!(accounts, installed_at:)
    group = install_group!(:serra, accounts)
    original = create_expense!(group:, creator: accounts.fetch(:bruno), payer: accounts.fetch(:ana), description: "Hospedagem", occurred_on: installed_at.to_date - 14, amount_text: "1.760,00", split: equal_split(accounts, %i[ana bruno carla diego]))
    ExpenseDescriptionEditor.call(group_id: group.id, expense_id: original.id, actor_user_id: accounts.fetch(:bruno).id, description: "Hospedagem revisada")
    ExpenseCorrector.call(group_id: group.id, expense_id: original.id, actor_user_id: accounts.fetch(:ana).id, reason: "Valor final da reserva", paid_by_user_id: accounts.fetch(:ana).id, description: "Hospedagem revisada", occurred_on: installed_at.to_date - 14, amount_text: "1.920,00", split: equal_split(accounts, %i[ana bruno carla diego]), expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)
    create_expense!(group:, creator: accounts.fetch(:ana), payer: accounts.fetch(:diego), description: "Carro alugado", occurred_on: installed_at.to_date - 11, amount_text: "2.480,00", split: exact_split(accounts, ana: "160,90", bruno: "460,89", carla: "551,40", diego: "1.306,81"))
    create_expense!(group:, creator: accounts.fetch(:diego), payer: accounts.fetch(:bruno), description: "Mercado da serra", occurred_on: installed_at.to_date - 9, amount_text: "463,27", split: equal_split(accounts, %i[ana bruno carla]))
    create_expense!(group:, creator: accounts.fetch(:carla), payer: accounts.fetch(:carla), description: "Passeio de trilha", occurred_on: installed_at.to_date - 7, amount_text: "360,00", split: equal_split(accounts, %i[bruno carla diego]))
    create_expense!(group:, creator: accounts.fetch(:bruno), payer: accounts.fetch(:ana), description: "Pedágios", occurred_on: installed_at.to_date - 5, amount_text: "148,50", split: exact_split(accounts, ana: "30,00", bruno: "50,00", carla: "30,00", diego: "38,50"))
    cancelled = report_payment!(group:, from: accounts.fetch(:carla), to: accounts.fetch(:ana), amount_text: "975,82")
    PaymentCanceller.call(group_id: group.id, payment_id: cancelled.id, actor_user_id: accounts.fetch(:carla).id, reason: "Transferência refeita no plano", idempotency_key: SecureRandom.uuid)
    report_payment!(group:, from: accounts.fetch(:carla), to: accounts.fetch(:ana), amount_text: "975,82")
    report_payment!(group:, from: accounts.fetch(:bruno), to: accounts.fetch(:diego), amount_text: "300,00")
  end

  def install_apartamento!(accounts, installed_at:)
    group = install_group!(:apartamento, accounts)
    create_expense!(group:, creator: accounts.fetch(:ana), payer: accounts.fetch(:bruno), description: "Caução", occurred_on: installed_at.to_date - 12, amount_text: "2.400,00", split: exact_split(accounts, bruno: "600,00", carla: "800,00", diego: "1.000,00"))
    create_expense!(group:, creator: accounts.fetch(:bruno), payer: accounts.fetch(:ana), description: "Móvel da Ana", occurred_on: installed_at.to_date - 10, amount_text: "900,00", split: exact_split(accounts, ana: "400,00", bruno: "500,00"))
    create_expense!(group:, creator: accounts.fetch(:diego), payer: accounts.fetch(:carla), description: "Aluguel", occurred_on: installed_at.to_date - 8, amount_text: "1.200,00", split: exact_split(accounts, ana: "899,99", carla: "100,01", diego: "200,00"))
    create_expense!(group:, creator: accounts.fetch(:carla), payer: accounts.fetch(:diego), description: "Instalação de internet", occurred_on: installed_at.to_date - 6, amount_text: "600,00", split: exact_split(accounts, ana: "600,00"))
    create_expense!(group:, creator: accounts.fetch(:bruno), payer: accounts.fetch(:ana), description: "Luz", occurred_on: installed_at.to_date - 4, amount_text: "199,99", split: equal_split(accounts, %i[ana bruno carla diego]))
  end

  def install_configuracao!(accounts, installed_at:)
    group = install_group!(:configuracao, accounts)
    memberships = group.memberships.index_by(&:user_id)
    MembershipOrderer.call(group_id: group.id, actor_user_id: accounts.fetch(:ana).id, membership_ids: %i[carla ana diego bruno].map { |key| memberships.fetch(accounts.fetch(key).id).id })
    GroupOwnershipTransfer.call(group_id: group.id, actor_user_id: accounts.fetch(:ana).id, new_owner_user_id: accounts.fetch(:diego).id)
    create_expense!(group:, creator: accounts.fetch(:ana), payer: accounts.fetch(:diego), description: "Itens da república", occurred_on: installed_at.to_date - 3, amount_text: "900,00", split: exact_split(accounts, ana: "300,00", carla: "300,00", diego: "300,00"))
    report_payment!(group:, from: accounts.fetch(:ana), to: accounts.fetch(:diego), amount_text: "150,00")
    MembershipDeactivator.call(group_id: group.id, actor_user_id: accounts.fetch(:diego).id, user_id: accounts.fetch(:bruno).id)
  end

  def install_casa_de_praia!(accounts, installed_at:)
    group = install_group!(:casa, accounts)
    [ [ :ana, :bruno, "Hospedagem", "4.800,00" ], [ :bruno, :carla, "Limpeza", "320,00" ], [ :carla, :diego, "Mercado", "640,00" ], [ :diego, :ana, "Combustível", "420,00" ] ].each_with_index do |(payer, creator, description, amount_text), index|
      create_expense!(group:, creator: accounts.fetch(creator), payer: accounts.fetch(payer), description:, occurred_on: installed_at.to_date - (30 - index), amount_text:, split: equal_split(accounts, %i[ana bruno carla diego]))
    end
    [ [ "120,00", "Refeições" ], [ "180,00", "Pedágios" ], [ "240,00", "Estacionamento" ], [ "96,00", "Bebidas" ], [ "64,00", "Farmácia" ] ].each_with_index do |(amount_text, category), round|
      %i[ana bruno carla diego].each_with_index do |payer, index|
        create_expense!(group:, creator: accounts.fetch(%i[bruno carla diego ana][index]), payer: accounts.fetch(payer), description: "#{category} — rodada #{round + 1}", occurred_on: installed_at.to_date - (25 - round * 4 - index), amount_text:, split: equal_split(accounts, %i[ana bruno carla diego]))
      end
    end
    create_expense!(group:, creator: accounts.fetch(:diego), payer: accounts.fetch(:ana), description: "Taxa final da casa", occurred_on: installed_at.to_date - 1, amount_text: "400,00", split: equal_split(accounts, %i[ana bruno carla diego]))
    [ [ :bruno, "1.325,00" ], [ :diego, "1.225,00" ], [ :carla, "1.005,00" ] ].each do |from, amount_text|
      payment = report_payment!(group:, from: accounts.fetch(from), to: accounts.fetch(:ana), amount_text:)
      PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: accounts.fetch(:ana).id, idempotency_key: SecureRandom.uuid)
    end
  end

  def install_proxima_viagem!(accounts)
    group = install_group!(:proxima, accounts)
    %i[bruno carla].each { |user| invite!(group:, owner: accounts.fetch(:ana), user: accounts.fetch(user)) }
    declined = invite!(group:, owner: accounts.fetch(:ana), user: accounts.fetch(:diego))
    GroupInvitationDecliner.call(invitation_id: declined.id, actor_user_id: accounts.fetch(:diego).id)
  end

  def install_churrasco!(accounts, installed_at:)
    group = install_group!(:churrasco, accounts)
    revoked = invite!(group:, owner: accounts.fetch(:carla), user: accounts.fetch(:diego))
    GroupInvitationRevoker.call(invitation_id: revoked.id, actor_user_id: accounts.fetch(:carla).id)
    expired = invite!(group:, owner: accounts.fetch(:carla), user: accounts.fetch(:bruno))
    expired.update!(expires_at: installed_at - 1.minute)
    GroupInvitationExpirer.call(invitation_id: expired.id)
    GroupArchiver.call(group_id: group.id, actor_user_id: accounts.fetch(:carla).id)
    GroupRestorer.call(group_id: group.id, actor_user_id: accounts.fetch(:carla).id)
    GroupArchiver.call(group_id: group.id, actor_user_id: accounts.fetch(:carla).id)
  end

  def install_group!(key, accounts)
    definition = MANIFEST.fetch(key)
    group = GroupCreator.call(owner_user_id: accounts.fetch(definition.fetch(:owner)).id, name: definition.fetch(:name))
    definition.fetch(:members).each do |member|
      user = accounts.fetch(member)
      invitation = GroupInvitationCreator.call(group_id: group.id, actor_user_id: accounts.fetch(definition.fetch(:owner)).id, invited_user_id: user.id)
      GroupInvitationAccepter.call(invitation_id: invitation.id, actor_user_id: user.id)
    end
    group
  end

  def invite!(group:, owner:, user:)
    GroupInvitationCreator.call(group_id: group.id, actor_user_id: owner.id, invited_user_id: user.id)
  end

  def create_expense!(group:, creator:, payer:, description:, occurred_on:, amount_text:, split:)
    ExpenseCreator.call(group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: payer.id, description:, occurred_on:, amount_text:, split:)
  end

  def exact_split(accounts, shares) = { type: :exact, shares: shares.map { |user, amount_text| { user_id: accounts.fetch(user).id, amount_text: } } }
  def equal_split(accounts, users) = { type: :equal, participant_user_ids: users.map { |user| accounts.fetch(user).id } }

  def report_payment!(group:, from:, to:, amount_text:)
    PaymentReporter.call(group_id: group.id, actor_user_id: from.id, from_user_id: from.id, to_user_id: to.id, amount_text:, expected_financial_state_version: group.reload.financial_state_version, idempotency_key: SecureRandom.uuid)
  end

  def validate_balances!
    Group.find_each do |group|
      official = GroupBalanceCalculator.call(group)
      projected = ProjectedBalanceCalculator.call(official, group.payments.reported)
      raise GroupBalanceCalculator::UnbalancedLedger, "saldo oficial desequilibrado" unless official.values.sum.zero?
      raise GroupBalanceCalculator::UnbalancedLedger, "saldo projetado desequilibrado" unless projected.values.sum.zero?
    end
  end
end
