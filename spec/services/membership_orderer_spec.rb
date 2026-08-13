require "rails_helper"

RSpec.describe MembershipOrderer do
  describe ".call" do
    it "reordena todos os memberships ativos e inativos em posições contíguas" do
      group = create(:group)
      owner = create(:user)
      first = create(:user)
      second = create(:user)
      owner_membership = create(:membership, group:, user: owner, role: :owner, position: 0)
      first_membership = create(:membership, group:, user: first, status: :inactive, position: 1)
      second_membership = create(:membership, group:, user: second, position: 2)

      ordered = described_class.call(group_id: group.id, actor_user_id: owner.id, membership_ids: [ second_membership.id, owner_membership.id, first_membership.id ])

      expect(ordered.map { |membership| [ membership.id, membership.position ] }).to eq(
        [ [ second_membership.id, 0 ], [ owner_membership.id, 1 ], [ first_membership.id, 2 ] ]
      )
      expect(group.reload.financial_state_version).to eq(0)
    end

    it "recusa lista incompleta ou duplicada" do
      group = create(:group)
      owner = create(:user)
      first = create(:user)
      second = create(:user)
      owner_membership = create(:membership, group:, user: owner, role: :owner, position: 0)
      first_membership = create(:membership, group:, user: first, position: 1)
      second_membership = create(:membership, group:, user: second, position: 2)

      [ [ owner_membership.id, first_membership.id ], [ owner_membership.id, first_membership.id, first_membership.id ] ].each do |membership_ids|
        expect {
          described_class.call(group_id: group.id, actor_user_id: owner.id, membership_ids:)
        }.to raise_error(GroupCommand::InvalidInput, "lista de memberships inválida")
      end

      expect(Membership.where(group:).order(:position).pluck(:id, :position)).to eq(
        [ [ owner_membership.id, 0 ], [ first_membership.id, 1 ], [ second_membership.id, 2 ] ]
      )
    end
  end
end
