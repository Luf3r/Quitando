require "open3"
require "rbconfig"
require "tempfile"

RSpec.describe "MoneyParser em Ruby puro" do
  def run_clean_ruby(script)
    Open3.capture3(RbConfig.ruby, "-e", script)
  end

  it "carrega e converte um valor real sem Rails, ActiveRecord ou ActiveSupport" do
    service_path = File.expand_path("../../app/services/money_parser", __dir__)
    script = <<~RUBY
      abort "framework já estava carregado" if defined?(Rails) || defined?(ActiveRecord) || defined?(ActiveSupport)
      require #{service_path.dump}
      abort "MoneyParser carregou framework" if defined?(Rails) || defined?(ActiveRecord) || defined?(ActiveSupport)
      abort "conversão isolada incorreta" unless MoneyParser.parse_cents("1.234,56") == 123_456
      puts "isolated-ok"
    RUBY

    stdout, stderr, status = run_clean_ruby(script)

    expect(status).to be_success, stderr
    expect(stdout).to include("isolated-ok")
    expect(stderr).to be_empty
  end

  it "detecta uma extensão indevida de ActiveSupport" do
    Tempfile.create([ "active-support-dependent", ".rb" ]) do |fixture|
      fixture.write("String.new('value').present?\n")
      fixture.flush

      _stdout, stderr, status = run_clean_ruby("require #{fixture.path.dump}")

      expect(status).not_to be_success
      expect(stderr).to include("undefined method 'present?'")
    end
  end
end
