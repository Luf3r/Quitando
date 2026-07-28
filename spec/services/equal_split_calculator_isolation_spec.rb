require "open3"
require "rbconfig"

RSpec.describe "EqualSplitCalculator em Ruby puro" do
  it "carrega e executa o serviço real sem Rails ou ActiveSupport" do
    service_path = File.expand_path("../../app/services/equal_split_calculator", __dir__)
    script = <<~RUBY
      abort "Rails já estava carregado" if defined?(Rails)
      abort "ActiveSupport já estava carregado" if defined?(ActiveSupport)
      require #{service_path.dump}
      abort "EqualSplitCalculator carregou Rails" if defined?(Rails)
      abort "EqualSplitCalculator carregou ActiveSupport" if defined?(ActiveSupport)

      membership = Data.define(:user_id, :position)
      result = EqualSplitCalculator.call(
        amount_cents: 5,
        memberships: [membership.new("payer", 0), membership.new("other", 1)],
        paid_by_user_id: "payer"
      )
      expected = [
        { user_id: "payer", amount_owed_cents: 3, position: 0 },
        { user_id: "other", amount_owed_cents: 2, position: 1 }
      ]
      abort "resultado isolado incorreto" unless result == expected
      puts "isolated-ok"
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script)

    expect(status).to be_success, stderr
    expect(stdout).to include("isolated-ok")
    expect(stderr).to be_empty
  end
end
