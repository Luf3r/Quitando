require "open3"
require "tempfile"

RSpec.describe "Structure SQL normalization command" do
  APP_ROOT = File.expand_path("../..", __dir__)
  NORMALIZER_COMMAND_PATH = File.join(APP_ROOT, "bin/normalize-structure-sql")
  CI_CONFIG_PATH = File.join(APP_ROOT, "config/ci.rb")

  it "normalizes the explicit structure file passed to the command" do
    Tempfile.create([ "structure", ".sql" ]) do |file|
      file.binmode
      file.write("CREATE TABLE examples ();\n\n".b)
      file.flush

      expect(File.executable?(NORMALIZER_COMMAND_PATH)).to be(true)

      _stdout, _stderr, status = Open3.capture3(NORMALIZER_COMMAND_PATH, file.path, chdir: APP_ROOT)

      expect(status).to be_success
      expect(File.binread(file.path)).to eq("CREATE TABLE examples ();\n".b)
    end
  end

  it "does not mutate structure.sql while CI prepares the test database" do
    steps = []
    runner = Object.new
    runner.define_singleton_method(:step) { |name, command| steps << [ name, command ] }
    recording_ci = Class.new
    recording_ci.define_singleton_method(:run) { |&block| runner.instance_exec(&block) }
    stub_const("CI", recording_ci)

    load CI_CONFIG_PATH

    expect(steps).to include(
      [
        "Setup: Test database",
        "env RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bin/rails db:prepare && bin/normalize-structure-sql"
      ]
    )
  end
end
