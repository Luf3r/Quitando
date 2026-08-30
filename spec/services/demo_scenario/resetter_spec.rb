require "rails_helper"

RSpec.describe DemoScenario::Resetter do
  let(:environment) do
    {
      "QUITANDO_DEMO_MODE" => "true",
      "QUITANDO_DEMO_DATABASE_NAME" => ActiveRecord::Base.connection_db_config.database,
      "QUITANDO_DEMO_PASSWORD" => "senha-publica",
      "CONFIRM_DEMO_RESET" => "quitando-demo-only"
    }
  end

  let(:config) { DemoScenario::Config.new(environment:) }

  it "rejects an unauthorized database before discovering or truncating tables" do
    observed_sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |_event, _start, _finish, _id, payload| observed_sql << payload[:sql] }
    resetter = described_class.new(config: DemoScenario::Config.new(environment: environment.merge("QUITANDO_DEMO_DATABASE_NAME" => "other_database")))

    expect { resetter.call(manual: true) }.to raise_error(DemoScenario::Config::UnauthorizedDatabase)
    expect(observed_sql.grep(/pg_tables|TRUNCATE/i)).to be_empty
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "requires the literal manual confirmation before discovering or truncating tables" do
    observed_sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |_event, _start, _finish, _id, payload| observed_sql << payload[:sql] }
    resetter = described_class.new(config: DemoScenario::Config.new(environment: environment.except("CONFIRM_DEMO_RESET")))

    expect { resetter.call(manual: true) }.to raise_error(DemoScenario::Config::ManualConfirmationMissing)
    expect(observed_sql.grep(/pg_tables|TRUNCATE/i)).to be_empty
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "discovers only primary application tables, excluding Rails metadata" do
    resetter = described_class.new(config:)

    expect(resetter.send(:truncatable_table_names)).to include("users", "demo_scenarios")
    expect(resetter.send(:truncatable_table_names)).not_to include("schema_migrations", "ar_internal_metadata")
  end

  it "retries lock contention at most five times using the injected interval" do
    sleeps = []
    resetter = described_class.new(config:, sleeper: ->(duration) { sleeps << duration })
    scenario = DemoScenario.new(key: "retry-result", version: 1, installed_at: Time.current, last_reset_at: Time.current)
    attempts = 0
    allow(resetter).to receive(:reset_once!) do
      attempts += 1
      raise ActiveRecord::LockWaitTimeout if attempts < 3

      scenario
    end

    expect(resetter.call(manual: true)).to eq(scenario)
    expect(sleeps).to eq([ 1.minute, 1.minute ])
    expect(resetter).to have_received(:reset_once!).exactly(3).times
  end

  it "emits sanitised lifecycle events" do
    preserved_user = create(:user, email: "preserve-on-reset-failure@example.test")
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.demo_scenario.reset") { |event| events << event.payload }
    resetter = described_class.new(config:, sleeper: ->(_) {}, installer: -> { raise "boom compra do mercado" })

    expect { resetter.call(manual: true) }.to raise_error(RuntimeError, "boom compra do mercado")
    expect(events.map { |event| event.fetch(:status) }).to eq(%i[start failure])
    expect(events.flatten.join).not_to include("compra do mercado")
    expect(User.find(preserved_user.id)).to eq(preserved_user)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "replaces a mutation with the canonical installation atomically" do
    mutated_user = create(:user, email: "mutacao-descartavel@example.test")
    installer = lambda do
      DemoScenario.create!(
        key: DemoScenario::Installer::SCENARIO_KEY,
        version: DemoScenario::Installer::SCENARIO_VERSION,
        installed_at: Time.current,
        last_reset_at: Time.current
      )
    end

    scenario = described_class.new(config:, installer:).call(manual: true)

    expect(scenario).to have_attributes(key: DemoScenario::Installer::SCENARIO_KEY, version: DemoScenario::Installer::SCENARIO_VERSION)
    expect(User.where(id: mutated_user.id)).to be_empty
    expect(DemoScenario.count).to eq(1)
  end
end
