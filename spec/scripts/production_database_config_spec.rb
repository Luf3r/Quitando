require "rails_helper"
require "open3"
require "rbconfig"

RSpec.describe "Neon production database configuration" do
  it "uses the exact database names and pooled endpoint credentials for real and demo" do
    {
      "false" => %w[Quitando quitando_cache quitando_queue quitando_cable],
      "true" => %w[Demo demo_cache demo_queue demo_cable]
    }.each do |demo_mode, expected_names|
      configuration = production_database_names(demo_mode)

      expected_host = demo_mode == "true" ? "ep-demo-pooler.c-2.sa-east-1.aws.neon.tech" : "ep-main-pooler.c-2.sa-east-1.aws.neon.tech"
      expect(configuration).to eq(expected_names.map { |name| [ name, expected_host, "owner" ] })
    end
  end

  private

  def production_database_names(demo_mode)
    demo = demo_mode == "true"
    project = demo ? "demo" : "main"
    names = demo ? %w[Demo demo_cache demo_queue demo_cable] : %w[Quitando quitando_cache quitando_queue quitando_cable]
    roles = %w[primary cache queue cable]
    environment = {
      "RAILS_ENV" => "production",
      "QUITANDO_DEMO_MODE" => demo_mode,
      "QUITANDO_MAIN_DATABASE_NAME" => demo ? nil : "Quitando",
      "QUITANDO_DEMO_DATABASE_NAME" => demo ? "Demo" : nil,
      "DB_HOST" => "legacy.example.test",
      "QUITANDO_DATABASE_PASSWORD" => "legacy-password"
    }

    roles.each_with_index do |role, index|
      variable = role == "primary" ? "DATABASE_URL" : "#{role.upcase}_DATABASE_URL"
      environment[variable] = "postgresql://owner:secret@ep-#{project}-pooler.c-2.sa-east-1.aws.neon.tech/#{names[index]}"
      environment["QUITANDO_#{role.upcase}_DATABASE_NAME"] = names[index] unless role == "primary"
    end

    source = <<~RUBY
      raw_configuration = YAML.safe_load(ERB.new(File.read("config/database.yml")).result, aliases: true)
      databases = ActiveRecord::DatabaseConfigurations.new(raw_configuration).configs_for(env_name: "production")
      puts JSON.generate(databases.map { |database| [database.database, database.configuration_hash[:host], database.configuration_hash[:username]] })
    RUBY
    output, status = Open3.capture2e(
      environment,
      RbConfig.ruby,
      "-ractive_record",
      "-ractive_record/database_configurations",
      "-rerb",
      "-ryaml",
      "-rjson",
      "-e",
      source,
      chdir: Rails.root.to_s
    )

    expect(status).to be_success, output
    JSON.parse(output)
  end
end
