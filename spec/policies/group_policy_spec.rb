require "rails_helper"

RSpec.describe GroupPolicy do
  describe "#update?" do
    it "autoriza somente membership owner ativa" do
      group = create(:group)
      owner = create(:user)
      member = create(:user)
      create(:membership, group:, user: owner, role: :owner, status: :active, position: 0)
      create(:membership, group:, user: member, role: :member, status: :active, position: 1)

      expect(described_class.new(owner, group)).to be_update
      expect(described_class.new(member, group)).not_to be_update
    end
  end

  describe "Scope" do
    it "inclui apenas grupos da membership ativa do usuário" do
      user = create(:user)
      active_group = create(:group)
      inactive_group = create(:group)
      create(:membership, group: active_group, user:, status: :active, position: 0)
      create(:membership, group: inactive_group, user:, status: :inactive, position: 0)

      expect(described_class::Scope.new(user, Group).resolve).to contain_exactly(active_group)
    end
  end
end
