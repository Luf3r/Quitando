require "rails_helper"

RSpec.describe Http::DomainErrorMapper do
  describe ".call" do
    it "mapeia entrada inválida de grupo para 422" do
      response = described_class.call(GroupCommand::InvalidInput.new("nome inválido"))

      expect(response).to have_attributes(status: :unprocessable_entity, i18n_key: "errors.unprocessable_entity", field: :name)
    end

    it "relança exceções que não pertencem ao contrato HTTP" do
      error = RuntimeError.new("ledger indisponível")

      expect { described_class.call(error) }.to raise_error(error)
    end
  end
end
