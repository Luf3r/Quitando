require "rails_helper"

invalid_persisted_ids = {
  "UUID v7 em maiúsculas" => "018F6D4E-06AC-7D62-8BD3-31A553F3A00B",
  "UUID v7 com variante RFC inválida" => "018f6d4e-06ac-7d62-7bd3-31a553f3a00b",
  "string malformada" => "não-é-um-uuid",
  "valor que não é string" => 123
}.freeze
valid_group_id = "018f6d4e-06ac-7d62-8bd3-31a553f3a00b"
valid_actor_user_id = "018f6d4e-06ac-7d62-8bd3-31a553f3a00c"

RSpec.describe GroupNameUpdater do
  describe ".call" do
    it "normaliza o nome quando o ator é owner ativo sem alterar a versão financeira" do
      group = create(:group, name: "Casa")
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)

      updated_group = described_class.call(group_id: group.id, actor_user_id: owner.id, name: "  Casa nova  ")

      expect(updated_group.reload).to have_attributes(name: "Casa nova", financial_state_version: 0)
    end

    invalid_persisted_ids.each do |invalid_id_description, invalid_id|
      it "rejeita group_id com #{invalid_id_description} antes de consultar grupos" do
        expect(Group).not_to receive(:find_by)

        expect {
          described_class.call(group_id: invalid_id, actor_user_id: valid_actor_user_id, name: "Casa")
        }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
      end

      it "rejeita actor_user_id com #{invalid_id_description} antes de consultar grupos" do
        expect(Group).not_to receive(:find_by)

        expect {
          described_class.call(group_id: valid_group_id, actor_user_id: invalid_id, name: "Casa")
        }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
      end
    end

    it "rejeita nome ausente ou em branco antes de abrir uma transação" do
      [ nil, 1, "", " \t\n " ].each do |name|
        expect(Group).not_to receive(:transaction)

        expect {
          described_class.call(
            group_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
            actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c",
            name:
          )
        }.to raise_error(GroupCommand::InvalidInput, "nome inválido")
      end
    end

    it "expõe ausência tipada para grupo inexistente" do
      actor = create(:user)
      group_id = "018f6d4e-06ac-7d62-8bd3-31a553f3a00b"

      expect {
        described_class.call(group_id:, actor_user_id: actor.id, name: "Casa")
      }.to raise_error(GroupCommand::NotFound, "grupo não encontrado")
    end

    it "recusa ator sem membership owner ativa" do
      group = create(:group)
      member = create(:user)
      create(:membership, group:, user: member, role: :member, position: 0)

      expect {
        described_class.call(group_id: group.id, actor_user_id: member.id, name: "Casa nova")
      }.to raise_error(GroupCommand::Forbidden, "membership owner ativa obrigatória")

      expect(group.reload.name).to eq("Casa")
    end

    it "recusa owner inativo" do
      group = create(:group)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, status: :inactive, position: 0)

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id, name: "Casa nova")
      }.to raise_error(GroupCommand::Forbidden, "membership owner ativa obrigatória")

      expect(group.reload.name).to eq("Casa")
    end

    it "recusa renomear grupo arquivado" do
      group = create(:group, archived_at: Time.current)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)

      expect {
        described_class.call(group_id: group.id, actor_user_id: owner.id, name: "Casa nova")
      }.to raise_error(GroupCommand::ArchivedGroup, "grupo arquivado")

      expect(group.reload.name).to eq("Casa")
    end
  end
end
