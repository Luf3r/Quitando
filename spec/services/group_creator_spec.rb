require "rails_helper"

invalid_persisted_ids = {
  "UUID v7 em maiúsculas" => "018F6D4E-06AC-7D62-8BD3-31A553F3A00B",
  "UUID v7 com variante RFC inválida" => "018f6d4e-06ac-7d62-7bd3-31a553f3a00b",
  "string malformada" => "não-é-um-uuid",
  "valor que não é string" => 123
}.freeze

RSpec.describe GroupCreator do
  describe ".call" do
    it "cria grupo BRL e owner ativo na posição zero na mesma transação" do
      owner = create(:user)

      group = described_class.call(owner_user_id: owner.id, name: "  Casa da praia  ")

      expect(group).to have_attributes(name: "Casa da praia", currency_code: "BRL", financial_state_version: 0)
      expect(group.memberships).to contain_exactly(
        have_attributes(user_id: owner.id, role: "owner", status: "active", position: 0)
      )
    end

    invalid_persisted_ids.each do |invalid_id_description, invalid_id|
      it "rejeita owner com #{invalid_id_description} antes de consultar usuários" do
        expect(User).not_to receive(:find_by)

        expect {
          described_class.call(owner_user_id: invalid_id, name: "Casa")
        }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
      end
    end

    it "rejeita nome ausente ou em branco antes de abrir uma transação" do
      [ nil, 1, "", " \t\n " ].each do |name|
        expect(Group).not_to receive(:transaction)

        expect {
          described_class.call(owner_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b", name:)
        }.to raise_error(GroupCommand::InvalidInput, "nome inválido")
      end
    end

    it "expõe ausência tipada quando o owner não existe" do
      owner_user_id = "018f6d4e-06ac-7d62-8bd3-31a553f3a00b"

      expect {
        described_class.call(owner_user_id:, name: "Casa")
      }.to raise_error(GroupCommand::NotFound, "usuário não encontrado")

      expect(Group.where(name: "Casa")).to be_empty
    end

    it "reverte o grupo quando a criação do membership falha" do
      owner = create(:user)
      callback = -> { raise "falha forçada na criação do membership" }
      Membership.set_callback(:create, :before, callback)

      expect {
        described_class.call(owner_user_id: owner.id, name: "Casa transitória")
      }.to raise_error(RuntimeError, "falha forçada na criação do membership")

      expect(Group.where(name: "Casa transitória")).to be_empty
    ensure
      Membership.skip_callback(:create, :before, callback) if callback
    end
  end
end
