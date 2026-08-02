require "rails_helper"

RSpec.describe "Rails boot" do
  it "carrega a aplicação Quitando" do
    expect(Rails.application.class.name).to eq("Quitando::Application")
  end

  it "inclui a autorização do Pundit no controller base" do
    expect(ApplicationController.ancestors).to include(Pundit::Authorization)
  end

  it "conecta ao PostgreSQL 18 real" do
    connection = ActiveRecord::Base.connection

    expect(connection).to be_active
    expect(connection.select_value("SHOW server_version_num").to_i / 10_000).to eq(18)
  end
end
