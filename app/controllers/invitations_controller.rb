class InvitationsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    authorize GroupInvitation, :index?
    GroupInvitation.where(status: :pending).where(expires_at: ..Time.current).find_each do |invitation|
      GroupInvitationExpirer.call(invitation_id: invitation.id)
    end
    @invitations = policy_scope(GroupInvitation).includes(:group, :invited_by_user)
  end

  def accept
    invitation = GroupInvitation.where(invited_user_id: current_user.id).find(params[:id])
    authorize invitation, :accept?
    GroupInvitationAccepter.call(invitation_id: invitation.id, actor_user_id: current_user.id)
    redirect_to group_path(invitation.group_id), status: :see_other
  end

  def decline
    invitation = GroupInvitation.where(invited_user_id: current_user.id).find(params[:id])
    authorize invitation, :decline?
    GroupInvitationDecliner.call(invitation_id: invitation.id, actor_user_id: current_user.id)
    redirect_to invitations_path, status: :see_other
  end
end
