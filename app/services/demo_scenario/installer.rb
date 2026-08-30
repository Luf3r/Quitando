class DemoScenario::Installer
  SCENARIO_KEY = "canonical-v1"
  SCENARIO_VERSION = 1
  PUBLIC_ACCOUNTS = {
    ana: "ana@demo.quitando.test",
    bruno: "bruno@demo.quitando.test",
    carla: "carla@demo.quitando.test",
    diego: "diego@demo.quitando.test"
  }.freeze

  def self.call(config: DemoScenario::Config.new)
    new(config:).call
  end

  def initialize(config:)
    @config = config
  end

  def call
    config.validate_installation!

    DemoScenario.transaction do
      DemoScenario::Lock.acquire!
      DemoScenario.find_by(key: SCENARIO_KEY) || install!
    end
  end

  private

  attr_reader :config

  def install!
    accounts = create_public_accounts!
    installed_at = Time.current

    install_serra!(accounts, installed_at:)
    install_apartamento!(accounts, installed_at:)
    install_casa_de_praia!(accounts, installed_at:)
    install_proxima_viagem!(accounts)
    install_churrasco!(accounts, installed_at:)
    install_configuracao!(accounts)

    validate_balances!
    DemoScenario.create!(key: SCENARIO_KEY, version: SCENARIO_VERSION, installed_at:, last_reset_at: installed_at)
  end

  def create_public_accounts!
    PUBLIC_ACCOUNTS.transform_values do |email|
      User.create!(email:, password: config.public_password, password_confirmation: config.public_password, demo_account: true)
    end
  end

  def install_serra!(accounts, installed_at:)
    group = create_group!(owner: accounts.fetch(:ana), name: "Viagem para a serra")
    accept_members!(group:, owner: accounts.fetch(:ana), users: accounts.values_at(:bruno, :carla, :diego))

    original = create_expense!(
      group:,
      creator: accounts.fetch(:ana),
      payer: accounts.fetch(:bruno),
      description: "Compra do mercado",
      occurred_on: installed_at.to_date - 8,
      amount_text: "10,00",
      split: exact_split(accounts.fetch(:ana) => "3,00", accounts.fetch(:bruno) => "1,00", accounts.fetch(:carla) => "6,00")
    )
    ExpenseDescriptionEditor.call(group_id: group.id, expense_id: original.id, actor_user_id: accounts.fetch(:ana).id, description: "Compra do mercado revisada")
    create_corrected_expense!(group:, original:, actor: accounts.fetch(:ana), payer: accounts.fetch(:bruno), occurred_on: installed_at.to_date - 8, accounts:)

    cancelled = report_payment!(group:, from: accounts.fetch(:ana), to: accounts.fetch(:bruno), amount_text: "1,00")
    PaymentCanceller.call(group_id: group.id, payment_id: cancelled.id, actor_user_id: accounts.fetch(:ana).id, reason: "Transferência refeita no plano", idempotency_key: SecureRandom.uuid)
    report_payment!(group:, from: accounts.fetch(:carla), to: accounts.fetch(:bruno), amount_text: "2,00")
  end

  def create_corrected_expense!(group:, original:, actor:, payer:, occurred_on:, accounts:)
    ExpenseCorrector.call(
      group_id: group.id,
      expense_id: original.id,
      actor_user_id: actor.id,
      reason: "Valores revisados",
      paid_by_user_id: payer.id,
      description: "Compra do mercado corrigida",
      occurred_on:,
      amount_text: "10,00",
      split: exact_split(accounts.fetch(:ana) => "3,00", accounts.fetch(:bruno) => "1,00", accounts.fetch(:carla) => "6,00"),
      expected_financial_state_version: group.reload.financial_state_version,
      idempotency_key: SecureRandom.uuid
    )
  end

  def install_apartamento!(accounts, installed_at:)
    group = create_group!(owner: accounts.fetch(:bruno), name: "Contas do apartamento")
    accept_members!(group:, owner: accounts.fetch(:bruno), users: accounts.values_at(:ana, :carla))
    create_expense!(
      group:,
      creator: accounts.fetch(:bruno),
      payer: accounts.fetch(:bruno),
      description: "Conta de luz",
      occurred_on: installed_at.to_date - 3,
      amount_text: "10,01",
      split: { type: :equal, participant_user_ids: accounts.values_at(:bruno, :ana, :carla).map(&:id) }
    )
  end

  def install_casa_de_praia!(accounts, installed_at:)
    group = create_group!(owner: accounts.fetch(:ana), name: "Casa de praia quitada")
    accept_members!(group:, owner: accounts.fetch(:ana), users: [ accounts.fetch(:bruno) ])

    24.times do |index|
      create_expense!(
        group:,
        creator: accounts.fetch(:ana),
        payer: accounts.fetch(:ana),
        description: "Despesa histórica #{index + 1}",
        occurred_on: installed_at.to_date - (30 - index),
        amount_text: "1,00",
        split: { type: :equal, participant_user_ids: accounts.values_at(:ana, :bruno).map(&:id) }
      )
    end

    2.times do
      payment = report_payment!(group:, from: accounts.fetch(:bruno), to: accounts.fetch(:ana), amount_text: "6,00")
      PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: accounts.fetch(:ana).id, idempotency_key: SecureRandom.uuid)
    end
  end

  def install_proxima_viagem!(accounts)
    group = create_group!(owner: accounts.fetch(:ana), name: "Próxima viagem")
    invite!(group:, owner: accounts.fetch(:ana), user: accounts.fetch(:bruno))
    invite!(group:, owner: accounts.fetch(:ana), user: accounts.fetch(:carla))
    declined = invite!(group:, owner: accounts.fetch(:ana), user: accounts.fetch(:diego))
    GroupInvitationDecliner.call(invitation_id: declined.id, actor_user_id: accounts.fetch(:diego).id)
  end

  def install_churrasco!(accounts, installed_at:)
    group = create_group!(owner: accounts.fetch(:carla), name: "Churrasco arquivado")
    revoked = invite!(group:, owner: accounts.fetch(:carla), user: accounts.fetch(:diego))
    GroupInvitationRevoker.call(invitation_id: revoked.id, actor_user_id: accounts.fetch(:carla).id)
    expired = invite!(group:, owner: accounts.fetch(:carla), user: accounts.fetch(:bruno))
    expired.update!(expires_at: installed_at - 1.minute)
    GroupInvitationExpirer.call(invitation_id: expired.id)
    GroupArchiver.call(group_id: group.id, actor_user_id: accounts.fetch(:carla).id)
    GroupRestorer.call(group_id: group.id, actor_user_id: accounts.fetch(:carla).id)
    GroupArchiver.call(group_id: group.id, actor_user_id: accounts.fetch(:carla).id)
  end

  def install_configuracao!(accounts)
    group = create_group!(owner: accounts.fetch(:ana), name: "Configuração da república")
    accept_members!(group:, owner: accounts.fetch(:ana), users: accounts.values_at(:bruno, :carla, :diego))
    memberships = group.memberships.index_by(&:user_id)
    MembershipOrderer.call(
      group_id: group.id,
      actor_user_id: accounts.fetch(:ana).id,
      membership_ids: accounts.values_at(:carla, :ana, :diego, :bruno).map { |account| memberships.fetch(account.id).id }
    )
    GroupOwnershipTransfer.call(group_id: group.id, actor_user_id: accounts.fetch(:ana).id, new_owner_user_id: accounts.fetch(:diego).id)
    MembershipDeactivator.call(group_id: group.id, actor_user_id: accounts.fetch(:diego).id, user_id: accounts.fetch(:bruno).id)
  end

  def create_group!(owner:, name:)
    GroupCreator.call(owner_user_id: owner.id, name:)
  end

  def accept_members!(group:, owner:, users:)
    users.each do |user|
      invitation = invite!(group:, owner:, user:)
      GroupInvitationAccepter.call(invitation_id: invitation.id, actor_user_id: user.id)
    end
  end

  def invite!(group:, owner:, user:)
    GroupInvitationCreator.call(group_id: group.id, actor_user_id: owner.id, invited_user_id: user.id)
  end

  def create_expense!(group:, creator:, payer:, description:, occurred_on:, amount_text:, split:)
    ExpenseCreator.call(
      group_id: group.id,
      created_by_user_id: creator.id,
      paid_by_user_id: payer.id,
      description:,
      occurred_on:,
      amount_text:,
      split:
    )
  end

  def exact_split(shares)
    { type: :exact, shares: shares.map { |user, amount_text| { user_id: user.id, amount_text: } } }
  end

  def report_payment!(group:, from:, to:, amount_text:)
    PaymentReporter.call(
      group_id: group.id,
      actor_user_id: from.id,
      from_user_id: from.id,
      to_user_id: to.id,
      amount_text:,
      expected_financial_state_version: group.reload.financial_state_version,
      idempotency_key: SecureRandom.uuid
    )
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
