require "rails_helper"

RSpec.describe "Bancos locais separados" do
  it "configura bancos primários independentes para o site real e a demo" do
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "development").index_by(&:name)

    expect(configs.fetch("primary").database).to eq("quitando_development")
    expect(configs.fetch("demo").database).to eq("quitando_demo_development")
    expect(Array(configs.fetch("demo").migrations_paths)).to eq([ "db/migrate" ])
  end
end
