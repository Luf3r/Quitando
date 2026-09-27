require "rails_helper"

RSpec.describe DemoScenarioResetJob do
  it "does nothing outside production demo mode" do
    resetter = instance_double(DemoScenario::Resetter)
    allow(DemoScenario::Resetter).to receive(:new).and_return(resetter)
    allow(resetter).to receive(:call)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))

    described_class.perform_now

    expect(resetter).not_to have_received(:call)
  end

  it "runs the scheduled reset only in production demo mode" do
    resetter = instance_double(DemoScenario::Resetter)
    allow(DemoScenario::Resetter).to receive(:new).and_return(resetter)
    allow(resetter).to receive(:call)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("QUITANDO_DEMO_MODE").and_return("true")

    described_class.perform_now

    expect(resetter).to have_received(:call).with(manual: false)
  end
end
