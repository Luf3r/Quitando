require "open3"
require "rbconfig"
require "tempfile"

RSpec.describe "DebtSimplifier em Ruby puro" do
  def run_clean_ruby(script)
    Open3.capture3(RbConfig.ruby, "-e", script)
  end

  it "carrega e executa o serviço real sem Rails ou ActiveRecord" do
    service_path = File.expand_path("../../app/services/debt_simplifier", __dir__)
    debtor_id = "018f0f3e-7b6c-7a10-8b2c-1234567890ab"
    creditor_id = "018f0f3e-7b6c-7a11-9b2c-1234567890ab"
    script = <<~RUBY
      abort "Rails já estava carregado" if defined?(Rails)
      abort "ActiveRecord já estava carregado" if defined?(ActiveRecord)
      require #{service_path.dump}
      abort "DebtSimplifier carregou Rails" if defined?(Rails)
      abort "DebtSimplifier carregou ActiveRecord" if defined?(ActiveRecord)

      transfer = DebtSimplifier::Transfer.new(
        from_user_id: #{debtor_id.dump},
        to_user_id: #{creditor_id.dump},
        amount_cents: 500
      )
      result = DebtSimplifier.new(
        #{debtor_id.dump} => -500,
        #{creditor_id.dump} => 500
      ).call
      abort "resultado isolado incorreto" unless result == [transfer]
      puts "isolated-ok"
    RUBY

    stdout, stderr, status = run_clean_ruby(script)

    expect(status).to be_success, stderr
    expect(stdout).to include("isolated-ok")
    expect(stderr).to be_empty
  end

  it "detecta uma dependência mínima e indevida de Rails" do
    Tempfile.create([ "rails-dependent", ".rb" ]) do |fixture|
      fixture.write("Rails.application\n")
      fixture.flush

      _stdout, stderr, status = run_clean_ruby("require #{fixture.path.dump}")

      expect(status).not_to be_success
      expect(stderr).to include("uninitialized constant Rails")
    end
  end
end
