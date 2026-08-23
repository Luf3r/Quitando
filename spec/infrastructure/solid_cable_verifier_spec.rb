require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "Solid Cable verifier safety" do
  VERIFIER_PATH = File.expand_path("../../bin/verify-solid-cable", __dir__)

  def run_verifier(test_database_url, environment = {})
    Open3.capture3(
      { "TEST_DATABASE_URL" => test_database_url }.merge(environment),
      RbConfig.ruby,
      VERIFIER_PATH
    )
  end

  def with_fake_dependencies(environment = {})
    Dir.mktmpdir("solid-cable-verifier-fakes") do |directory|
      statements_path = File.join(directory, "statements.log")
      process_path = File.join(directory, "process.log")
      fake_system_path = File.join(directory, "fake_system.rb")

      File.write(
        File.join(directory, "pg.rb"),
        <<~'RUBY'
          module PG
            class FakeConnection
              def escape_identifier(value)
                %("#{value}")
              end

              def exec(statement)
                File.open(ENV.fetch("SOLID_CABLE_PG_LOG"), "a") { |log| log.puts(statement) }
                raise "simulated CREATE DATABASE failure" if statement.start_with?("CREATE DATABASE") && ENV["SOLID_CABLE_CREATE_FAILURE"] == "true"
                raise "simulated DROP DATABASE failure" if statement.start_with?("DROP DATABASE") && ENV["SOLID_CABLE_DROP_FAILURE"] == "true"
              end
            end

            def self.connect(_url, **options)
              File.open(ENV.fetch("SOLID_CABLE_PROCESS_LOG"), "a") do |log|
                log.puts("CONNECT #{options.sort.map { |key, value| "#{key}=#{value}" }.join(" ")}")
              end
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

            @fake_pid = 8_000
            @commands = {}
            @wait_attempts = Hash.new(0)

            class << self
              def spawn(environment, *arguments)
                options = arguments.last.is_a?(Hash) ? arguments.pop : {}
                @fake_pid += 1
                @commands[@fake_pid] = environment
                File.open(ENV.fetch("SOLID_CABLE_PROCESS_LOG"), "a") do |log|
                  log.puts("SPAWN pgroup=#{options[:pgroup].inspect} #{arguments.join(' ')}")
                end
                @fake_pid
              end

              def wait2(pid)
                @wait_attempts[pid] += 1
                sleep 1 if ENV["SOLID_CABLE_COMMAND_TIMEOUT"] == "true" && @wait_attempts[pid] == 1
                sleep 1 if ENV["SOLID_CABLE_UNCONFIRMED_TERMINATION"] == "true"

                successful = ENV["SOLID_CABLE_COMMAND_FAILURE"] != "true"
                [ pid, FakeStatus.new(successful, successful ? 0 : 17) ]
              end

              def kill(signal, pid)
                File.open(ENV.fetch("SOLID_CABLE_PROCESS_LOG"), "a") { |log| log.puts("KILL #{signal} #{pid}") }
                1
              end
            end
          end
        RUBY
      )

      stdout, stderr, status = Open3.capture3(
        {
          "RUBYLIB" => directory,
          "RUBYOPT" => "-r#{fake_system_path}",
          "SOLID_CABLE_PG_LOG" => statements_path,
          "SOLID_CABLE_PROCESS_LOG" => process_path,
          "TEST_DATABASE_URL" => "postgresql://user:password@localhost/quitando_test"
        }.merge(environment),
        RbConfig.ruby,
        VERIFIER_PATH
      )

      statements = File.exist?(statements_path) ? File.readlines(statements_path, chomp: true) : []
      process = File.exist?(process_path) ? File.readlines(process_path, chomp: true) : []
      yield stdout, stderr, status, statements, process
    end
  end

  it "rejects a dbname query parameter before a database mutation" do
    _stdout, stderr, status = run_verifier("postgresql://user:password@127.0.0.1:1/safe?dbname=other")

    expect(status).not_to be_success
    expect(stderr).to include("TEST_DATABASE_URL must not contain a dbname query parameter")
  end

  it "does not remove a database when creating it fails" do
    with_fake_dependencies("SOLID_CABLE_CREATE_FAILURE" => "true") do |_stdout, stderr, status, statements|
      expect(status).not_to be_success
      expect(stderr).to include("simulated CREATE DATABASE failure")
      expect(statements).to match([ a_string_starting_with("SET statement_timeout"), a_string_starting_with("CREATE DATABASE") ])
      expect(statements).not_to include(a_string_starting_with("DROP DATABASE"))
    end
  end

  it "uses bounded PostgreSQL connections and removes exactly its created database" do
    with_fake_dependencies do |stdout, _stderr, status, statements, process|
      created_name = statements.grep(/^CREATE DATABASE/).fetch(0).match(/"([^"]+)"/)[1]

      expect(status).to be_success
      expect(created_name).to match(/\Aquitando_solid_cable_\d+_[0-9a-f]+\z/)
      expect(statements).to include(%(DROP DATABASE IF EXISTS "#{created_name}"))
      expect(stdout).to include("Removed temporary Solid Cable database: #{created_name}")
      expect(process.grep(/^CONNECT /)).to all(include("connect_timeout=30"))
      expect(process.grep(/^SPAWN /)).to all(start_with("SPAWN pgroup=true "))
    end
  end

  it "preserves a primary verification failure when cleanup also fails" do
    with_fake_dependencies(
      "SOLID_CABLE_COMMAND_FAILURE" => "true",
      "SOLID_CABLE_DROP_FAILURE" => "true"
    ) do |_stdout, stderr, status, statements|
      expect(status.exitstatus).to eq(17)
      expect(statements.grep(/^DROP DATABASE/)).not_to be_empty
      expect(stderr).to include("command failed with exit 17")
      expect(stderr).to include("simulated DROP DATABASE failure")
    end
  end

  it "terminates a timed-out child process before cleanup" do
    with_fake_dependencies(
      "SOLID_CABLE_COMMAND_TIMEOUT" => "true",
      "SOLID_CABLE_COMMAND_TIMEOUT_SECONDS" => "0.01"
    ) do |_stdout, stderr, status, statements, process|
      expect(status).not_to be_success
      expect(stderr).to include("command timed out")
      expect(process).to include(a_string_starting_with("KILL TERM -"))
      expect(statements.grep(/^DROP DATABASE/)).not_to be_empty
    end
  end

  it "retains the temporary database when process termination remains unconfirmed" do
    with_fake_dependencies(
      "SOLID_CABLE_UNCONFIRMED_TERMINATION" => "true",
      "SOLID_CABLE_COMMAND_TIMEOUT_SECONDS" => "0.01",
      "SOLID_CABLE_COMMAND_TERMINATION_GRACE_SECONDS" => "0.01"
    ) do |stdout, stderr, status, statements, process|
      expect(status).not_to be_success
      expect(stderr).to include("process termination was not confirmed")
      expect(stdout).to include("Retained temporary Solid Cable database")
      expect(statements.grep(/^DROP DATABASE/)).to be_empty
      expect(process).to include(a_string_starting_with("KILL TERM -"))
      expect(process).to include(a_string_starting_with("KILL KILL -"))
    end
  end

  it "publishes and consumes through Solid Cable on PostgreSQL" do
    stdout, stderr, status = run_verifier(ENV.fetch("TEST_DATABASE_URL"))

    expect(status).to be_success, stderr
    expect(stdout).to include("Removed temporary Solid Cable database")
  end
end
