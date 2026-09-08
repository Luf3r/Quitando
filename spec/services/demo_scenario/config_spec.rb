require "rails_helper"

RSpec.describe DemoScenario::Config do
  let(:database_name) { ActiveRecord::Base.connection_db_config.database }
  let(:environment) do
    {
      "QUITANDO_DEMO_MODE" => "true",
      "QUITANDO_DEMO_DATABASE_NAME" => database_name,
      "QUITANDO_DEMO_PASSWORD" => "senha-publica",
      "CONFIRM_DEMO_RESET" => "quitando-demo-only"
    }
  end

  describe "#validate_installation!" do
    it "aceita somente uma configuração demo explicitamente autorizada" do
      config = described_class.new(environment:)

      expect(config.validate_installation!).to be(config)
      expect(config.public_password).to eq("senha-publica")
    end

    it "rejeita modo demo ausente ou diferente do literal true" do
      config = described_class.new(
        environment: environment.merge("QUITANDO_DEMO_MODE" => "1"),
      )

      expect { config.validate_installation! }
        .to raise_error(DemoScenario::Config::DemoModeDisabled)
    end

    it "rejeita senha pública ausente" do
      config = described_class.new(
        environment: environment.merge("QUITANDO_DEMO_PASSWORD" => "  "),
      )

      expect { config.validate_installation! }
        .to raise_error(DemoScenario::Config::PublicPasswordMissing)
    end

    it "rejeita o banco que não corresponde exatamente ao banco autorizado sem apagar dados" do
      user = create(:user)
      config = described_class.new(
        environment: environment.merge("QUITANDO_DEMO_DATABASE_NAME" => "quitando_demo"),
      )

      expect { config.validate_installation! }
        .to raise_error(DemoScenario::Config::UnauthorizedDatabase)
      expect(User.find(user.id)).to eq(user)
    end
  end

  describe "#validate_reset!" do
    it "rejeita confirmação manual ausente ou diferente do literal exigido" do
      config = described_class.new(
        environment: environment.merge("CONFIRM_DEMO_RESET" => "confirmar"),
      )

      expect { config.validate_reset! }
        .to raise_error(DemoScenario::Config::ManualConfirmationMissing)
    end

    it "aceita a confirmação manual literal após validar a instalação" do
      config = described_class.new(environment:)

      expect(config.validate_reset!).to be(config)
    end
  end
end
