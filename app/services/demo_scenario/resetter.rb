class DemoScenario::Resetter
  ATTEMPTS = 5
  RETRY_INTERVAL = 1.minute
  EXCLUDED_TABLES = %w[ar_internal_metadata schema_migrations].freeze
  EVENT_NAME = "quitando.demo_scenario.reset".freeze

  def self.call(config: DemoScenario::Config.new, manual: false)
    new(config:).call(manual:)
  end

  def initialize(config:, sleeper: ->(duration) { sleep duration }, installer: nil)
    @config = config
    @sleeper = sleeper
    @installer = installer || -> { DemoScenario::Installer.call(config:) }
  end

  def call(manual:)
    instrument(:start)

    attempt = 0
    begin
      validate!(manual:)
      attempt += 1
      scenario = reset_once!
      instrument(:success, attempt:)
      scenario
    rescue ActiveRecord::LockWaitTimeout
      if attempt < ATTEMPTS
        retry_after_contention!(attempt)
        retry
      end

      instrument(:failure, attempt:)
      raise
    rescue StandardError
      instrument(:failure, attempt:)
      raise
    end
  end

  private

  attr_reader :config, :installer, :sleeper

  def validate!(manual:)
    manual ? config.validate_reset! : config.validate_installation!
  end

  def reset_once!
    DemoScenario.transaction do
      connection.execute("SET LOCAL lock_timeout = '10s'")
      connection.execute("SET LOCAL statement_timeout = '60s'")
      DemoScenario::Lock.acquire!
      truncate_primary_tables!
      scenario = installer.call
      scenario.update!(last_reset_at: Time.current)
      scenario
    end
  end

  def truncatable_table_names
    connection.tables - EXCLUDED_TABLES
  end

  def truncate_primary_tables!
    table_names = truncatable_table_names
    raise "nenhuma tabela primária encontrada para reset demo" if table_names.empty?

    connection.truncate_tables(*table_names)
  end

  def retry_after_contention!(attempt)
    sleeper.call(RETRY_INTERVAL)
    true
  end

  def instrument(status, attempt: nil)
    payload = { status: }
    payload[:attempt] = attempt if attempt
    ActiveSupport::Notifications.instrument(EVENT_NAME, payload)
  end

  def connection
    ApplicationRecord.connection
  end
end
