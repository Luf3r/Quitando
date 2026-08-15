require "rails_helper"

RSpec.describe MembershipPolicy do
  it "permite saída ao próprio membro e administração ao owner ativo" do
    owner = create(:user)
    member = create(:user)
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    membership = create(:membership, group:, user: member, position: 1)

    expect(described_class.new(member, membership)).to be_deactivate
    expect(described_class.new(owner, membership)).to be_reactivate
    expect(described_class.new(owner, membership)).to be_transfer_ownership
    expect(described_class.new(member, membership)).not_to be_reactivate
  end
end
