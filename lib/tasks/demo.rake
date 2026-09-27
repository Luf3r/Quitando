namespace :demo do
  desc "Atomically reset the explicitly authorised shared demo database"
  task reset: :environment do
    DemoScenario::Resetter.call(manual: true)
  end
end
