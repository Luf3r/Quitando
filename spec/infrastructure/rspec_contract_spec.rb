require "open3"
require "tempfile"

RSpec.describe "RSpec CLI contract" do
  def run_rspec(source, environment = {})
    Tempfile.create([ "rspec-contract", "_spec.rb" ]) do |fixture|
      fixture.write(source)
      fixture.flush

      Open3.capture3(
        environment,
        Gem.ruby,
        Gem.bin_path("rspec-core", "rspec"),
        fixture.path,
        "--format",
        "progress",
        "--no-color",
        chdir: File.expand_path("../..", __dir__)
      )
    end
  end

  it "fails when no examples are discovered" do
    _output, _error, status = run_rspec("")

    expect(status).not_to be_success
  end

  it "runs focused and non-focused examples in CI" do
    output, _error, status = run_rspec(<<~RUBY, "CI" => "true")
      RSpec.describe "CI focus fixture" do
        it("passes", :focus) { expect(true).to be(true) }
        it("fails") { expect(false).to be(true) }
      end
    RUBY

    expect(status).not_to be_success
    expect(output).to include("2 examples, 1 failure")
  end

  it "keeps focus available outside CI" do
    output, _error, status = run_rspec(<<~RUBY, "CI" => nil)
      RSpec.describe "local focus fixture" do
        it("passes", :focus) { expect(true).to be(true) }
        it("would fail") { expect(false).to be(true) }
      end
    RUBY

    expect(status).to be_success
    expect(output).to include("1 example, 0 failures")
  end
end
