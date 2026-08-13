require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "Financial schema migration verifier safety" do
  MIGRATION_SCRIPT_PATH = File.expand_path("../../bin/verify-financial-schema-migrations", __dir__)

  def run_verifier(test_database_url)
    Open3.capture3(
      { "TEST_DATABASE_URL" => test_database_url },
      RbConfig.ruby,
      MIGRATION_SCRIPT_PATH
    )
  end

  def with_fake_migration_dependencies(environment = {})
    Dir.mktmpdir("financial-migration-fakes") do |fake_directory|
      log_path = File.join(fake_directory, "statements.log")
      process_log_path = File.join(fake_directory, "process.log")
      fake_system_path = File.join(fake_directory, "fake_system.rb")

      File.write(
        File.join(fake_directory, "pg.rb"),
        <<~'RUBY'
          module PG
            class FakeConnection
              def escape_identifier(value)
                %("#{value}")
              end

              def exec(statement)
                if statement.start_with?("SET statement_timeout")
                  File.open(ENV.fetch("PROCESS_FAKE_LOG"), "a") { |log| log.puts("STATEMENT #{statement}") }
                else
                  File.open(ENV.fetch("PG_FAKE_LOG"), "a") { |log| log.puts(statement) }
                end

                if statement.start_with?("CREATE DATABASE") && ENV["PG_FAKE_CREATE_FAILURE"] == "true"
                  raise "simulated CREATE DATABASE collision"
                end

                if statement.start_with?("DROP DATABASE") && ENV["PG_FAKE_DROP_FAILURE"] == "true"
                  raise "simulated DROP DATABASE failure"
                end
              end
            end

            def self.connect(_url, **options)
              details = options.sort.map { |key, value| "#{key}=#{value}" }.join(" ")
              File.open(ENV.fetch("PROCESS_FAKE_LOG"), "a") { |log| log.puts("CONNECT #{details}") }
              yield FakeConnection.new
            end
          end
        RUBY
      )
      File.write(
        fake_system_path,
        <<~'RUBY'
          module Process
            FakeStatus = Struct.new(:successful, :code) do
              def success? = successful
              def exitstatus = code
            end

            @fake_pid = 4_000
            @wait_attempts = Hash.new(0)
            @commands = {}

            class << self
              def spawn(environment, *arguments)
                options = arguments.last.is_a?(Hash) ? arguments.pop : {}
                command = arguments.join(" ")
                File.open(ENV.fetch("PROCESS_FAKE_LOG"), "a") do |log|
                  log.puts("SPAWN pgroup=#{options[:pgroup].inspect} #{command}")
                end
                @fake_pid += 1
                @commands[@fake_pid] = [ environment, command ]
                @fake_pid
              end

              def wait2(pid)
                @wait_attempts[pid] += 1
                sleep 1 if ENV["SYSTEM_FAKE_TIMEOUT"] == "true" && @wait_attempts[pid] == 1

                environment, command = @commands.fetch(pid)
                expected_phase_nine_down_failure = environment["FINANCIAL_MIGRATION_EXPECT_FAILURE"] == "true"
                successful = ENV["SYSTEM_FAKE_FAILURE"] != "true" && !expected_phase_nine_down_failure
                [ pid, FakeStatus.new(successful, successful ? 0 : 17) ]
              end

              def kill(signal, pid)
                File.open(ENV.fetch("PROCESS_FAKE_LOG"), "a") { |log| log.puts("KILL #{signal} #{pid}") }
                1
              end
            end
          end
        RUBY
      )

      stdout, stderr, status = Open3.capture3(
        {
          "PG_FAKE_LOG" => log_path,
          "PROCESS_FAKE_LOG" => process_log_path,
          "RUBYLIB" => fake_directory,
          "RUBYOPT" => "-r#{fake_system_path}",
          "TEST_DATABASE_URL" => "postgresql://user:password@localhost/quitando_test"
        }.merge(environment),
        RbConfig.ruby,
        MIGRATION_SCRIPT_PATH
      )
      statements = File.exist?(log_path) ? File.readlines(log_path, chomp: true) : []
      orchestration = File.exist?(process_log_path) ? File.readlines(process_log_path, chomp: true) : []

      yield stdout, stderr, status, statements, orchestration
    end
  end

  it "rejects a decoded dbname query parameter before any database mutation", :aggregate_failures do
    [ "dbname", "%64bname" ].each do |query_key|
      stdout, stderr, status = run_verifier(
        "postgresql://user:password@127.0.0.1:1/safe_database?#{query_key}=wrong_database"
      )

      expect(status).not_to be_success
      expect(stdout).not_to include("Temporary database")
      expect(stderr).to include("TEST_DATABASE_URL must not contain a dbname query parameter")
    end
  end

  it "does not disclose credentials when TEST_DATABASE_URL is invalid", :aggregate_failures do
    secret = "migration-verifier-secret"
    stdout, stderr, status = run_verifier("postgresql://user:#{secret}@[")

    expect(status).not_to be_success
    expect(stderr).to include("TEST_DATABASE_URL is invalid")
    expect(stdout).not_to include(secret)
    expect(stderr).not_to include(secret)
  end

  it "does not drop a database when CREATE DATABASE fails" do
    with_fake_migration_dependencies("PG_FAKE_CREATE_FAILURE" => "true") do |_stdout, stderr, status, statements|
      expect(status).not_to be_success
      expect(stderr).to include("simulated CREATE DATABASE collision")
      expect(statements).to match([ a_string_starting_with("CREATE DATABASE") ])
    end
  end

  it "removes exactly the database it created after a successful primary path", :aggregate_failures do
    with_fake_migration_dependencies do |stdout, _stderr, status, statements, orchestration|
      created_name = statements.fetch(0).match(/CREATE DATABASE "([^"]+)"/)[1]

      expect(status).to be_success
      expect(statements).to eq(
        [
          %(CREATE DATABASE "#{created_name}"),
          %(DROP DATABASE IF EXISTS "#{created_name}")
        ]
      )
      expect(stdout).to include("Removed temporary database: #{created_name}")
      expect(orchestration.grep(/^CONNECT /)).to eq([ "CONNECT connect_timeout=30", "CONNECT connect_timeout=30" ])
      expect(orchestration.grep(/^STATEMENT /)).to eq(
        [ "STATEMENT SET statement_timeout = '30s'", "STATEMENT SET statement_timeout = '30s'" ]
      )
      expect(orchestration.grep(/^SPAWN /)).not_to be_empty
      expect(orchestration.grep(/^SPAWN /)).to all(start_with("SPAWN pgroup=true "))
    end
  end

  it "runs the payment command receipt SQLSTATE assertion before the structural RSpec suite" do
    with_fake_migration_dependencies do |_stdout, _stderr, status, _statements, orchestration|
      expect(status).to be_success
      expect(orchestration).to include(a_string_including("payment command receipt mutation expected SQLSTATE 55000"))
    end
  end

  it "runs the cutover backfill and final index assertions before the structural RSpec suite" do
    with_fake_migration_dependencies do |_stdout, _stderr, status, _statements, orchestration|
      expect(status).to be_success
      expect(orchestration).to include(a_string_including("cutover backfill expected exactly one report receipt"))
      expect(orchestration).to include(a_string_including("payments idempotency audit index expected non-unique"))
    end
  end

  it "runs the migration lock timeout restoration assertion before the structural RSpec suite" do
    with_fake_migration_dependencies do |_stdout, _stderr, status, _statements, orchestration|
      expect(status).to be_success
      expect(orchestration).to include(a_string_including("lock_timeout was not restored after cutover receipt migration"))
    end
  end

  it "runs the phase 10 schema round-trip and lock timeout assertion before the structural RSpec suite" do
    with_fake_migration_dependencies do |_stdout, _stderr, status, _statements, orchestration|
      expect(status).to be_success
      expect(orchestration).to include(a_string_including("lock_timeout was not restored after phase 10 group schema migration"))
    end
  end

  it "cleans up after a primary failure and preserves that failure", :aggregate_failures do
    with_fake_migration_dependencies("SYSTEM_FAKE_FAILURE" => "true") do |_stdout, stderr, status, statements|
      expect(status).not_to be_success
      expect(statements.map { |statement| statement.split.first }).to eq(%w[CREATE DROP])
      expect(stderr).to include("command failed")
      expect(stderr).not_to include("cleanup also failed")
    end
  end

  it "terminates a timed-out command, cleans up and preserves the timeout failure", :aggregate_failures do
    with_fake_migration_dependencies(
      "SYSTEM_FAKE_TIMEOUT" => "true",
      "FINANCIAL_MIGRATION_COMMAND_TIMEOUT_SECONDS" => "0.01"
    ) do |_stdout, stderr, status, statements, orchestration|
      expect(status).not_to be_success
      expect(statements.map { |statement| statement.split.first }).to eq(%w[CREATE DROP])
      expect(stderr).to include("command timed out")
      expect(orchestration.grep(/^SPAWN /)).to all(start_with("SPAWN pgroup=true "))
      expect(orchestration.grep(/^KILL /)).to eq([ "KILL TERM -4001" ])
    end
  end

  it "preserves the primary failure when cleanup also fails", :aggregate_failures do
    with_fake_migration_dependencies(
      "SYSTEM_FAKE_FAILURE" => "true",
      "PG_FAKE_DROP_FAILURE" => "true"
    ) do |_stdout, stderr, status, statements|
      expect(status).not_to be_success
      expect(statements.map { |statement| statement.split.first }).to eq(%w[CREATE DROP])
      expect(stderr).to include("cleanup also failed: simulated DROP DATABASE failure")
      expect(stderr).to include("command failed")
    end
  end

  it "fails when cleanup alone fails", :aggregate_failures do
    with_fake_migration_dependencies("PG_FAKE_DROP_FAILURE" => "true") do |_stdout, stderr, status, statements|
      expect(status).not_to be_success
      expect(statements.map { |statement| statement.split.first }).to eq(%w[CREATE DROP])
      expect(stderr).to include("simulated DROP DATABASE failure")
      expect(stderr).not_to include("command failed")
    end
  end
end
