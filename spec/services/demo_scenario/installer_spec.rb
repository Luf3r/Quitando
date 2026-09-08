require "rails_helper"

RSpec.describe "DemoScenario::Installer" do
  include ActiveSupport::Testing::TimeHelpers

  let(:config) do
    DemoScenario::Config.new(
      environment: {
        "QUITANDO_DEMO_MODE" => "true",
        "QUITANDO_DEMO_DATABASE_NAME" => ActiveRecord::Base.connection_db_config.database,
        "QUITANDO_DEMO_PASSWORD" => "senha-publica"
      }
    )
  end

  it "instala as contas públicas, grupos e estados canônicos somente após validar a configuração" do
    installed_at = Time.zone.parse("2026-08-30 12:00:00")

    travel_to(installed_at) { DemoScenario::Installer.call(config:) }

    expect(User.where(demo_account: true).order(:email).pluck(:name, :email)).to eq(
      [
        [ "Ana", "ana@demo.quitando.test" ],
        [ "Bruno", "bruno@demo.quitando.test" ],
        [ "Carla", "carla@demo.quitando.test" ],
        [ "Diego", "diego@demo.quitando.test" ]
      ]
    )
    expect(User.where(demo_account: true).all? { |user| user.valid_password?("senha-publica") }).to be(true)
    expect(Group.order(:name).pluck(:name)).to eq(
      [
        "Casa de praia quitada",
        "Churrasco arquivado",
        "Configuração da república",
        "Contas do apartamento",
        "Próxima viagem",
        "Viagem para a serra"
      ]
    )

    viagem = Group.find_by!(name: "Viagem para a serra")
    contas = Group.find_by!(name: "Contas do apartamento")
    casa = Group.find_by!(name: "Casa de praia quitada")
    proxima = Group.find_by!(name: "Próxima viagem")
    churrasco = Group.find_by!(name: "Churrasco arquivado")
    configuracao = Group.find_by!(name: "Configuração da república")

    expect(GroupFinancialStatusResolver.call(viagem)).to eq(:awaiting_confirmation)
    ana = User.find_by!(email: "ana@demo.quitando.test")
    bruno = User.find_by!(email: "bruno@demo.quitando.test")
    carla = User.find_by!(email: "carla@demo.quitando.test")
    diego = User.find_by!(email: "diego@demo.quitando.test")
    expect([ User.where(demo_account: true).count, Group.count, Expense.count, Payment.count, GroupInvitation.count, Membership.count, DemoScenario.count ]).to eq([ 4, 6, 37, 7, 18, 19, 1 ])
    replacement = viagem.expenses.find_by!(description: "Hospedagem revisada")
    expect(replacement).to have_attributes(created_by_user_id: ana.id, paid_by_user_id: ana.id, amount_cents: 192_000)
    expect(replacement.replaces_expense).to have_attributes(voided_at: be_present, voided_by_user_id: ana.id, amount_cents: 176_000)
    expect(viagem.expenses.where(voided_at: nil).count).to eq(5)
    expect(ExpenseDescriptionRevision.where(expense: viagem.expenses).count).to eq(1)
    expect(viagem.payments.pluck(:status)).to contain_exactly("cancelled", "reported", "reported")
    expect(GroupBalanceCalculator.call(viagem)).to eq(
      ana.id => 124_318, bruno.id => -80_205, carla.id => -97_582, diego.id => 53_469
    )
    expect(ProjectedBalanceCalculator.call(GroupBalanceCalculator.call(viagem), viagem.payments.reported)).to eq(
      ana.id => 26_736, bruno.id => -50_205, carla.id => 0, diego.id => 23_469
    )
    expect(GroupOverviewQuery.call(group: viagem, viewer: ana).settlement_plan.map { |transfer| [ transfer.from_user_id, transfer.to_user_id, transfer.amount_cents ] }).to eq(
      [ [ bruno.id, ana.id, 26_736 ], [ bruno.id, diego.id, 23_469 ] ]
    )

    residual_expense = contas.expenses.find_by!(description: "Luz")
    expect(residual_expense.expense_shares.order(:position).pluck(:amount_owed_cents)).to eq([ 5_000, 5_000, 5_000, 4_999 ])
    expect(GroupBalanceCalculator.call(contas)).to eq(
      ana.id => -85_000, bruno.id => 125_000, carla.id => 24_999, diego.id => -64_999
    )
    expect(GroupOverviewQuery.call(group: contas, viewer: ana).settlement_plan.map { |transfer| [ transfer.from_user_id, transfer.to_user_id, transfer.amount_cents ] }).to eq(
      [ [ ana.id, bruno.id, 85_000 ], [ diego.id, bruno.id, 40_000 ], [ diego.id, carla.id, 24_999 ] ]
    )
    expect(GroupFinancialStatusResolver.call(contas)).to eq(:open)
    expect(GroupFinancialStatusResolver.call(casa)).to eq(:settled)
    expect(casa.payments).to all(be_confirmed)
    expect(casa.expenses.count).to eq(25)
    expect(GroupHistoryQuery.page(group: casa, number: 1)).to have_attributes(total_facts: 28, total_pages: 2)
    expect(GroupFinancialStatusResolver.call(proxima)).to eq(:empty)
    expect(proxima.group_invitations.pluck(:status)).to contain_exactly("pending", "pending", "declined")
    expect(churrasco.archived_at).to be_present
    expired_invitation = churrasco.group_invitations.find_by!(status: :expired)
    expect(expired_invitation.expires_at).to eq(installed_at - 1.minute)
    expect(expired_invitation.expired_at).to be >= installed_at
    expect(configuracao.memberships.order(:position).pluck(:user_id)).to eq([ carla.id, ana.id, diego.id, bruno.id ])
    expect(configuracao.memberships.find_by!(user: diego)).to be_owner
    expect(configuracao.memberships.find_by!(user: bruno)).to be_inactive
    expect(GroupBalanceCalculator.call(configuracao)).to eq(ana.id => -30_000, bruno.id => 0, carla.id => -30_000, diego.id => 60_000)
    expect(ProjectedBalanceCalculator.call(GroupBalanceCalculator.call(configuracao), configuracao.payments.reported)).to eq(ana.id => -15_000, bruno.id => 0, carla.id => -30_000, diego.id => 45_000)
    cards = GroupListQuery.call(groups: Group.joins(:memberships).where(memberships: { user_id: ana.id }), viewer: ana)
    expect(cards.map { |card| card.group.name }).to eq([ "Viagem para a serra", "Configuração da república", "Contas do apartamento", "Próxima viagem", "Casa de praia quitada", "Churrasco arquivado" ])
    expect(cards.map { |card| GroupOverviewPresenter.new(snapshot: GroupOverviewQuery.call(group: card.group, viewer: ana), viewer_id: ana.id, archived: card.archived).primary_action }).to eq(
      %i[review_received follow_sent report_transfer add_expense settled archived]
    )

    expect(GroupInvitation.pluck(:status)).to include("pending", "accepted", "declined", "revoked", "expired")
    expect(Payment.pluck(:status)).to include("reported", "confirmed", "cancelled")
    expect(Membership.pluck(:status)).to include("active", "inactive")
    expect(Group.all).to all(satisfy { |group| GroupBalanceCalculator.call(group).values.sum.zero? })
    expect(Group.all).to all(satisfy { |group|
      balances = GroupBalanceCalculator.call(group)
      ProjectedBalanceCalculator.call(balances, group.payments.reported).values.sum.zero?
    })
    expect(DemoScenario.find_by!(key: "canonical-v2")).to have_attributes(version: 2, installed_at:, last_reset_at: installed_at)
  end

  it "não duplica o cenário em uma segunda instalação" do
    DemoScenario::Installer.call(config:)

    expect { DemoScenario::Installer.call(config:) }
      .not_to change { [ User.where(demo_account: true).count, Group.count, Expense.count, Payment.count, GroupInvitation.count, Membership.count, DemoScenario.count ] }
  end

  it "valida a instalação antes de criar qualquer conta pública" do
    invalid_config = DemoScenario::Config.new(
      environment: {
        "QUITANDO_DEMO_MODE" => "false",
        "QUITANDO_DEMO_DATABASE_NAME" => ActiveRecord::Base.connection_db_config.database,
        "QUITANDO_DEMO_PASSWORD" => "senha-publica"
      }
    )

    expect { DemoScenario::Installer.call(config: invalid_config) }
      .to raise_error(DemoScenario::Config::DemoModeDisabled)
    expect(User.where(demo_account: true)).to be_empty
    expect(DemoScenario.all).to be_empty
  end

  it "reverte a instalação inteira quando um comando de domínio falha" do
    allow(ExpenseCreator).to receive(:call).and_raise(ExpenseCreator::InvalidExpense, "falha de cenário")

    expect { DemoScenario::Installer.call(config:) }
      .to raise_error(ExpenseCreator::InvalidExpense, "falha de cenário")
    expect([ User.where(demo_account: true).count, Group.count, Expense.count, Payment.count, GroupInvitation.count, Membership.count, DemoScenario.count ]).to all(eq(0))
  end

  it "recusa marcador canônico incompatível antes de criar registros" do
    DemoScenario.create!(key: "canonical-v1", version: 1, installed_at: Time.current, last_reset_at: Time.current)

    expect { DemoScenario::Installer.call(config:) }.to raise_error(/cenário demo incompatível/)
    expect([ User.where(demo_account: true).count, Group.count, Expense.count, Payment.count, GroupInvitation.count, Membership.count, DemoScenario.count ]).to eq([ 0, 0, 0, 0, 0, 0, 1 ])
  end
end
