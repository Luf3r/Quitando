require "open3"
require "rbconfig"
require "tempfile"

RSpec.describe "FinancialMigrationCommandRunner em Ruby puro" do
  def run_clean_ruby(script)
    Open3.capture3(RbConfig.ruby, "-e", script)
  end

  it "carrega e executa um comando real sem Rails, ActiveRecord ou ActiveSupport" do
    runner_path = File.expand_path("../../lib/financial_migration_command_runner", __dir__)
    script = <<~RUBY
      abort "framework já estava carregado" if defined?(Rails) || defined?(ActiveRecord) || defined?(ActiveSupport)
      require "rbconfig"
      require #{runner_path.dump}
      abort "FinancialMigrationCommandRunner carregou framework" if defined?(Rails) || defined?(ActiveRecord) || defined?(ActiveSupport)
      status = FinancialMigrationCommandRunner.new(timeout_seconds: 1, termination_grace_seconds: 1).call(
        RbConfig.ruby,
        "-e",
        "exit 0",
        environment: {}
      )
      abort "comando isolado falhou" unless status.success?
      puts "isolated-ok"
    RUBY

    stdout, stderr, status = run_clean_ruby(script)

    expect(status).to be_success, stderr
    expect(stdout).to include("isolated-ok")
    expect(stderr).to be_empty
  end

  it "detecta uma referência indevida a ActiveSupport" do
    Tempfile.create([ "active-support-dependent", ".rb" ]) do |fixture|
      fixture.write("ActiveSupport::Notifications.instrument('event')\n")
      fixture.flush

      _stdout, stderr, status = run_clean_ruby("require #{fixture.path.dump}")

      expect(status).not_to be_success
      expect(stderr).to include("uninitialized constant ActiveSupport")
    end
  end
end
