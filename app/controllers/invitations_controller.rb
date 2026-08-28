class InvitationsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    authorize GroupInvitation, :index?
    visible_invitations = policy_scope(GroupInvitation)
    page = invitation_history_page
    return unless page

    visible_invitations.pending.where(expires_at: ..Time.current).find_each do |invitation|
      GroupInvitationExpirer.call(invitation_id: invitation.id)
    end
    @pending_page = GroupInvitationHistoryQuery.pending_page(invitations: visible_invitations, number: page)
    @terminal_page = GroupInvitationHistoryQuery.terminal_page(invitations: visible_invitations, number: page)
  end

  def accept
    invitation = GroupInvitation.where(invited_user_id: current_user.id).find(params[:id])
    authorize invitation, :accept?
    GroupInvitationAccepter.call(invitation_id: invitation.id, actor_user_id: current_user.id)
    respond_with_refresh(location: group_path(invitation.group_id))
  end

  def decline
    invitation = GroupInvitation.where(invited_user_id: current_user.id).find(params[:id])
    authorize invitation, :decline?
    GroupInvitationDecliner.call(invitation_id: invitation.id, actor_user_id: current_user.id)
    respond_with_refresh(location: invitations_path)
  end

  private

  def invitation_history_page
    page = params.fetch(:page, "1")
    return page.to_i if page.is_a?(String) && /\A[1-9]\d*\z/.match?(page)

    render plain: t("errors.unprocessable_entity"), status: :unprocessable_content
    nil
  end
end
