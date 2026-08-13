require "rails_helper"

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

    it "rejeita owner UUID v7 não canônico antes de abrir uma transação" do
      expect(Group).not_to receive(:transaction)

      expect {
        described_class.call(owner_user_id: SecureRandom.uuid, name: "Casa")
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
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
