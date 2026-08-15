require "rails_helper"

RSpec.describe GroupInvitationPolicy do
  it "autoriza aceitar ou recusar somente o usuário convidado" do
    invited_user = create(:user)
    other_user = create(:user)
    invitation = create(:group_invitation, invited_user:)

    expect(described_class.new(invited_user, invitation)).to be_accept
    expect(described_class.new(invited_user, invitation)).to be_decline
    expect(described_class.new(other_user, invitation)).not_to be_accept
  end

  it "limita o escopo aos convites pendentes do usuário" do
    user = create(:user)
    visible = create(:group_invitation, invited_user: user, status: :pending)
    hidden = create(:group_invitation, status: :pending)

    expect(described_class::Scope.new(user, GroupInvitation).resolve).to contain_exactly(visible)
    expect(described_class::Scope.new(user, GroupInvitation).resolve).not_to include(hidden)
  end
end
