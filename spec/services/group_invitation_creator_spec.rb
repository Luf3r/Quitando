require "rails_helper"

RSpec.describe GroupInvitationCreator do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    it "cria convite pending para uma conta sem membership ativa" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      invitation = travel_to(Time.zone.parse("2026-08-14 12:00:00")) do
        described_class.call(group_id: group.id, actor_user_id: owner.id, invited_user_id: invited_user.id)
      end

      expect(invitation).to have_attributes(
        group_id: group.id,
        invited_user_id: invited_user.id,
        invited_by_user_id: owner.id,
        status: "pending"
      )
      expect(invitation.expires_at).to eq(Time.zone.parse("2026-08-21 12:00:00"))
      expect(Membership.where(group:, user: invited_user, status: :active)).to be_empty
    end

    it "rejeita IDs inválidos antes de consultar o grupo" do
      expect(Group).not_to receive(:lock)

      expect {
        described_class.call(
          group_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
          actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c",
          invited_user_id: "não-é-um-uuid"
        )
      }.to raise_error(GroupCommand::InvalidInput, "identificadores inválidos")
    end

    it "expira pendência vencida sob o lock do grupo antes de criar novo convite" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      expired_pending = create(
        :group_invitation,
        group:,
        invited_user:,
        invited_by_user: owner,
        expires_at: 1.minute.ago
      )
      create(:membership, group:, user: owner, role: :owner, position: 0)

      invitation = described_class.call(
        group_id: group.id,
        actor_user_id: owner.id,
        invited_user_id: invited_user.id
      )

      expect(expired_pending.reload).to be_expired
      expect(expired_pending.expired_at).to be_present
      expect(invitation).to be_pending
    end

    it "traduz convite pendente duplicado para transição inválida" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      create(:group_invitation, group:, invited_user:, invited_by_user: owner, expires_at: 2.days.from_now)

      expect {
        described_class.call(
          group_id: group.id,
          actor_user_id: owner.id,
          invited_user_id: invited_user.id
        )
      }.to raise_error(GroupCommand::InvalidTransition, "convite pendente já existe")
    end

    it "recusa convidar usuário que já possui membership ativa" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      create(:membership, group:, user: invited_user, role: :member, position: 1)

      expect {
        described_class.call(
          group_id: group.id,
          actor_user_id: owner.id,
          invited_user_id: invited_user.id
        )
      }.to raise_error(GroupCommand::InvalidTransition, "usuário já possui membership ativa")
    end

    it "recusa ator sem membership owner ativa" do
      group = create(:group)
      member = create(:user)

      expect {
        described_class.call(
          group_id: group.id,
          actor_user_id: member.id,
          invited_user_id: create(:user).id
        )
      }.to raise_error(GroupCommand::Forbidden, "membership owner ativa obrigatória")
    end

    it "expõe ausência tipada para conta convidada inexistente" do
      group = create(:group)
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)

      expect {
        described_class.call(
          group_id: group.id,
          actor_user_id: owner.id,
          invited_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b"
        )
      }.to raise_error(GroupCommand::NotFound, "usuário não encontrado")
    end

    it "não aceita vencimento fornecido pelo chamador" do
      expect {
        described_class.call(
          group_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
          actor_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c",
          invited_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00d",
          expires_at: 1.year.from_now
        )
      }.to raise_error(ArgumentError, /expires_at/)
    end
  end
end
