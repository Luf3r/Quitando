class GroupInvitationsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def create
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :invite?
    invited_user = User.find_by(email: invitation_params[:email])
    return render_unprocessable_entity unless invited_user

    GroupInvitationCreator.call(group_id: group.id, actor_user_id: current_user.id, invited_user_id: invited_user.id)
    redirect_to group_path(group), status: :see_other
  end

  def revoke
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :invite?
    invitation = GroupInvitation.where(group:).find(params[:id])
    GroupInvitationRevoker.call(invitation_id: invitation.id, actor_user_id: current_user.id)
    redirect_to group_path(group), status: :see_other
  end

  private

  def invitation_params
    params.require(:invitation).permit(:email)
  end
end
