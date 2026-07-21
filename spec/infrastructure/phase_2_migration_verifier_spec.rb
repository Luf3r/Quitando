require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "Phase 2 migration verifier safety" do
  MIGRATION_SCRIPT_PATH = File.expand_path("../../bin/verify-phase-2-migrations", __dir__)

  def run_verifier(test_database_url)
    Open3.capture3(
      { "TEST_DATABASE_URL" => test_database_url },
      RbConfig.ruby,
      MIGRATION_SCRIPT_PATH
    )
  end

  def with_fake_migration_dependencies(environment = {})
    Dir.mktmpdir("phase-2-migration-fakes") do |fake_directory|
      log_path = File.join(fake_directory, "statements.log")
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
                File.open(ENV.fetch("PG_FAKE_LOG"), "a") { |log| log.puts(statement) }

                if statement.start_with?("CREATE DATABASE") && ENV["PG_FAKE_CREATE_FAILURE"] == "true"
                  raise "simulated CREATE DATABASE collision"
                end

                if statement.start_with?("DROP DATABASE") && ENV["PG_FAKE_DROP_FAILURE"] == "true"
                  raise "simulated DROP DATABASE failure"
                end
              end
            end

            def self.connect(_url)
              yield FakeConnection.new
            end
          end
        RUBY
      )
      File.write(
        fake_system_path,
        <<~'RUBY'
          module Kernel
            def system(*)
              ENV["SYSTEM_FAKE_FAILURE"] != "true"
            end
          end
        RUBY
      )

      stdout, stderr, status = Open3.capture3(
        {
          "PG_FAKE_LOG" => log_path,
          "RUBYLIB" => fake_directory,
          "RUBYOPT" => "-r#{fake_system_path}",
          "TEST_DATABASE_URL" => "postgresql://user:password@localhost/quitando_test"
        }.merge(environment),
        RbConfig.ruby,
        MIGRATION_SCRIPT_PATH
      )
      statements = File.exist?(log_path) ? File.readlines(log_path, chomp: true) : []

      yield stdout, stderr, status, statements
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
    with_fake_migration_dependencies do |stdout, _stderr, status, statements|
      created_name = statements.fetch(0).match(/CREATE DATABASE "([^"]+)"/)[1]

      expect(status).to be_success
      expect(statements).to eq(
        [
          %(CREATE DATABASE "#{created_name}"),
          %(DROP DATABASE IF EXISTS "#{created_name}")
        ]
      )
      expect(stdout).to include("Removed temporary database: #{created_name}")
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
