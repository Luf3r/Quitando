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
    Dir.mktmpdir("phase-2-migration-pg-fake") do |fake_library_directory|
      log_path = File.join(fake_library_directory, "statements.log")
      File.write(
        File.join(fake_library_directory, "pg.rb"),
        <<~'RUBY'
          module PG
            class FakeConnection
              def escape_identifier(value)
                %("#{value}")
              end

              def exec(statement)
                File.open(ENV.fetch("PG_FAKE_LOG"), "a") { |log| log.puts(statement) }
                raise "simulated CREATE DATABASE collision" if statement.start_with?("CREATE DATABASE")
              end
            end

            def self.connect(_url)
              yield FakeConnection.new
            end
          end
        RUBY
      )

      _stdout, stderr, status = Open3.capture3(
        {
          "PG_FAKE_LOG" => log_path,
          "RUBYLIB" => fake_library_directory,
          "TEST_DATABASE_URL" => "postgresql://user:password@localhost/quitando_test"
        },
        RbConfig.ruby,
        MIGRATION_SCRIPT_PATH
      )

      expect(status).not_to be_success
      expect(stderr).to include("simulated CREATE DATABASE collision")
      expect(File.readlines(log_path, chomp: true)).to match(
        [ a_string_starting_with("CREATE DATABASE") ]
      )
    end
  end
end
