# FactoryBot carrega todo .rb deste diretório durante a inicialização do Rails.
# Nesse carregamento interno, a spec precisa permanecer apenas como arquivo de spec.
unless defined?(Rails) && !Rails.application.initialized?
  require "rails_helper"

  RSpec.describe "FactoryBot factories" do
    it "persiste todas as factories e traits registradas" do
      FactoryBot.lint(traits: true)
    end
  end
end
