require "open3"
require "rbconfig"

RSpec.describe "Phase 2 migration verifier safety" do
  SCRIPT_PATH = File.expand_path("../../bin/verify-phase-2-migrations", __dir__)

  def run_verifier(test_database_url)
    Open3.capture3(
      { "TEST_DATABASE_URL" => test_database_url },
      RbConfig.ruby,
      SCRIPT_PATH
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
end
