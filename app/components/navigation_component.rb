class NavigationComponent < ApplicationComponent
  def initialize(user: nil, pending_invitation_count: 0)
    @user = user
    @pending_invitation_count = pending_invitation_count
  end

  private

  attr_reader :user, :pending_invitation_count
end
