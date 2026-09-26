# Seeds are opt-in for each operational profile. Local dual-host development
# installs the public scenario only on its dedicated demo shard.
if ENV["QUITANDO_DEMO_MODE"] == "true"
  DemoScenario::Installer.call
elsif LocalEnvironment.dual_database? && (Rails.env.development? || ENV["QUITANDO_SEED_LOCAL_DEMO"] == "true")
  ApplicationRecord.connected_to(role: :writing, shard: :demo) do
    DemoScenario::Installer.call
  end
end
