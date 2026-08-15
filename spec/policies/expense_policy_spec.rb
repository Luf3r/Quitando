require "rails_helper"

RSpec.describe ExpensePolicy do
  it "permite correção somente ao creator, pagador ou owner ativo" do
    owner = create(:user)
    member = create(:user)
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = create(:expense, group:, created_by_user: owner, paid_by_user: owner)

    expect(described_class.new(owner, expense)).to be_correct
    expect(described_class.new(member, expense)).not_to be_correct
  end
end
