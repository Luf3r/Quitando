require "rails_helper"
require "open3"
require "rbconfig"

RSpec.describe "demo scenario verifier" do
  let(:verifier_path) { Rails.root.join("bin/verify-demo-scenario").to_s }

  it "rejects a decoded dbname query parameter before opening a database connection" do
    [ "dbname", "%64bname" ].each do |query_key|
      _stdout, stderr, status = Open3.capture3(
        { "TEST_DATABASE_URL" => "postgresql://user:password@127.0.0.1:1/safe_database?#{query_key}=wrong_database" },
        RbConfig.ruby,
        verifier_path
      )

      expect(status).not_to be_success
      expect(stderr).to include("TEST_DATABASE_URL must not contain a dbname query parameter")
    end
  end
end
