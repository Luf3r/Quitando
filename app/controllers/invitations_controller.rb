class InvitationsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    authorize GroupInvitation, :index?
    visible_invitations = policy_scope(GroupInvitation)
    pages = invitation_history_pages
    return unless pages

    visible_invitations.pending.where(expires_at: ..Time.current).find_each do |invitation|
      GroupInvitationExpirer.call(invitation_id: invitation.id)
    end
    @pending_page = GroupInvitationHistoryQuery.pending_page(invitations: visible_invitations, number: pages.fetch(:pending))
    @terminal_page = GroupInvitationHistoryQuery.terminal_page(invitations: visible_invitations, number: pages.fetch(:closed))
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

  def invitation_history_pages
    legacy_page = params[:page]
    pending_page = params.fetch(:pending_page, legacy_page || "1")
    closed_page = params.fetch(:closed_page, legacy_page || "1")
    return { pending: pending_page.to_i, closed: closed_page.to_i } if valid_page?(pending_page) && valid_page?(closed_page)

    render plain: t("errors.unprocessable_entity"), status: :unprocessable_content
    nil
  end

  def valid_page?(page)
    page.is_a?(String) && /\A[1-9]\d*\z/.match?(page)
  end
end
