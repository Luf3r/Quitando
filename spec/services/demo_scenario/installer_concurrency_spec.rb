require "rails_helper"
require "timeout"

RSpec.describe "DemoScenario::Installer concurrency", :non_transactional do
  self.use_transactional_tests = false

  it "returns one canonical installation to two PostgreSQL sessions racing before the marker commits" do
    ready = Queue.new
    release_first_installation = Queue.new
    second_session_started = Queue.new
    backend_pids = Queue.new
    results = Queue.new
    config = demo_config
    created_resources = nil

    expect(DemoScenario.where(key: DemoScenario::Installer::SCENARIO_KEY)).to be_empty
    expect(User.where(email: DemoScenario::Installer::PUBLIC_ACCOUNTS.values)).to be_empty

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        connection.transaction do
          scenario = DemoScenario::Installer.call(config:)
          ready << [ scenario, capture_created_resources!(scenario) ]
          release_first_installation.pop
          results << scenario
        end
      end
    rescue StandardError => error
      ready << error
      results << error
    end

    first_backend_pid = Timeout.timeout(10) { backend_pids.pop }
    first_result, created_resources = Timeout.timeout(10) { ready.pop }
    raise first_result if first_result.is_a?(StandardError)

    second_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '5s'")
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        second_session_started << true
        results << DemoScenario::Installer.call(config:)
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(10) { second_session_started.pop }
    second_backend_pid = Timeout.timeout(10) { backend_pids.pop }
    expect(second_backend_pid).not_to eq(first_backend_pid)
    expect(wait_for_lock(second_backend_pid)).to eq("Lock")

    release_first_installation << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    values = 2.times.map { Timeout.timeout(10) { results.pop } }

    expect(values).to all(be_a(DemoScenario))
    expect(values.map(&:id).uniq).to eq([ first_result.id ])
    expect(DemoScenario.where(key: DemoScenario::Installer::SCENARIO_KEY).count).to eq(1)
    expect(User.where(demo_account: true).count).to eq(4)
    expect(Group.count).to eq(6)
  ensure
    primary_error = $!
    begin
      release_first_installation << true if release_first_installation
      threads = [ first_thread, second_thread ].compact
      threads.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { threads.each(&:join) }
      remove_demo_installation!(created_resources)
    rescue StandardError => cleanup_error
      warn "demo installer concurrency cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  it "leaves a pre-existing canonical marker untouched when no example resources were captured" do
    scenario = DemoScenario.create!(
      key: DemoScenario::Installer::SCENARIO_KEY,
      version: DemoScenario::Installer::SCENARIO_VERSION,
      installed_at: Time.current,
      last_reset_at: Time.current
    )

    remove_demo_installation!

    expect(DemoScenario.find(scenario.id)).to eq(scenario)
  ensure
    DemoScenario.where(id: scenario&.id).delete_all
  end

  def demo_config
    DemoScenario::Config.new(
      environment: {
        "QUITANDO_DEMO_MODE" => "true",
        "QUITANDO_DEMO_DATABASE_NAME" => ActiveRecord::Base.connection_db_config.database,
        "QUITANDO_DEMO_PASSWORD" => "senha-publica"
      }
    )
  end

  def wait_for_lock(backend_pid)
    Timeout.timeout(5) do
      loop do
        wait_event_type = ApplicationRecord.connection.select_value(
          ApplicationRecord.sanitize_sql_array([ "SELECT wait_event_type FROM pg_stat_activity WHERE pid = ?", backend_pid ])
        )
        return wait_event_type if wait_event_type == "Lock"

        sleep 0.02
      end
    end
  end

  def capture_created_resources!(scenario)
    accounts = User.where(email: DemoScenario::Installer::PUBLIC_ACCOUNTS.values).pluck(:id, :email).to_h
    group_ids = Membership.where(user_id: accounts.keys).distinct.pluck(:group_id)
    groups = Group.where(id: group_ids).pluck(:id, :name).to_h

    raise "contas demo incompletas" unless accounts.length == 4
    raise "grupos demo incompletos" unless groups.length == 6

    { scenario: [ scenario.id, scenario.key ], accounts:, groups: }
  end

  def remove_demo_installation!(resources = nil)
    return unless resources

    scenario_id, scenario_key = resources.fetch(:scenario)
    accounts = resources.fetch(:accounts)
    groups = resources.fetch(:groups)
    account_ids = accounts.keys
    group_ids = groups.keys
    raise "marcador demo inesperado" unless DemoScenario.where(id: scenario_id, key: scenario_key).count == 1
    raise "contas demo inesperadas" unless User.where(id: account_ids).pluck(:id, :email).to_h == accounts
    raise "grupos demo inesperados" unless Group.where(id: group_ids).pluck(:id, :name).to_h == groups

    payment_ids = Payment.where(group_id: group_ids).pluck(:id)
    expense_ids = Expense.where(group_id: group_ids).pluck(:id)

    ApplicationRecord.transaction do
      receipts = FinancialCommandReceipt.where(payment_id: payment_ids).or(FinancialCommandReceipt.where(expense_id: expense_ids))
      delete_payment_command_receipts_for_cleanup!(receipts)
      Payment.where(id: payment_ids).delete_all
      delete_expense_description_revisions_for_cleanup!(ExpenseDescriptionRevision.where(expense_id: expense_ids))
      delete_expense_history_for_cleanup!(Expense.where(id: expense_ids))
      GroupInvitation.where(group_id: group_ids).delete_all
      Membership.where(group_id: group_ids).delete_all
      Group.where(id: group_ids).delete_all
      DemoScenario.where(id: scenario_id, key: scenario_key).delete_all
      User.where(id: account_ids).delete_all
    end
  end
end
