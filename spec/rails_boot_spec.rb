require "rails_helper"

RSpec.describe "Rails boot" do
  it "carrega a aplicação Quitando" do
    expect(Rails.application.class.name).to eq("Quitando::Application")
  end

  it "inclui a autorização do Pundit no controller base" do
    expect(ApplicationController.ancestors).to include(Pundit::Authorization)
  end
end
