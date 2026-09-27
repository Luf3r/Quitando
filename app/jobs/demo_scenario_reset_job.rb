class DemoScenarioResetJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.env.production? && ENV["QUITANDO_DEMO_MODE"] == "true"

    DemoScenario::Resetter.new(config: DemoScenario::Config.new).call(manual: false)
  end
end
