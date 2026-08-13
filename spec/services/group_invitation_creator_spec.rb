require "rails_helper"

RSpec.describe GroupInvitationCreator do
  describe ".call" do
    it "cria convite pending para uma conta sem membership ativa" do
      group = create(:group)
      owner = create(:user)
      invited_user = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)
      expires_at = 2.days.from_now

      invitation = described_class.call(
        group_id: group.id,
        actor_user_id: owner.id,
        invited_user_id: invited_user.id,
        expires_at:
      )

      expect(invitation).to have_attributes(
        group_id: group.id,
        invited_user_id: invited_user.id,
        invited_by_user_id: owner.id,
        status: "pending"
      )
      expect(invitation.expires_at).to be_within(0.000001).of(expires_at)
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
        invited_user_id: invited_user.id,
        expires_at: 2.days.from_now
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
          invited_user_id: invited_user.id,
          expires_at: 3.days.from_now
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
          invited_user_id: invited_user.id,
          expires_at: 2.days.from_now
        )
      }.to raise_error(GroupCommand::InvalidTransition, "usuário já possui membership ativa")
    end

    it "recusa vencimento ausente, passado ou não temporal antes de abrir transação" do
      owner_id = "018f6d4e-06ac-7d62-8bd3-31a553f3a00b"
      invited_user_id = "018f6d4e-06ac-7d62-8bd3-31a553f3a00c"

      [ nil, 1, Time.current, 1.minute.ago ].each do |expires_at|
        expect(Group).not_to receive(:transaction)

        expect {
          described_class.call(group_id: owner_id, actor_user_id: owner_id, invited_user_id:, expires_at:)
        }.to raise_error(GroupCommand::InvalidInput, "vencimento inválido")
      end
    end
  end
end
