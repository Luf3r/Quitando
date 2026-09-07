class GroupsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    authorize Group, :index?
    @group_cards = GroupListQuery.call(groups: policy_scope(Group), viewer: current_user)
    pending_invitations = policy_scope(GroupInvitation).pending
    pending_invitations.where(expires_at: ..Time.current).find_each do |invitation|
      GroupInvitationExpirer.call(invitation_id: invitation.id)
    end
    @invitations = pending_invitations.includes(:group, :invited_by_user).to_a
  end

  def create
    authorize Group, :create?
    GroupCreator.call(owner_user_id: current_user.id, name: group_params[:name])

    respond_with_refresh(location: groups_path)
  end

  def show
    @group = policy_scope(Group).find(params[:id])
    authorize @group
    @overview = GroupOverviewQuery.call(group: @group, viewer: current_user)
    @summary = GroupOverviewPresenter.new(snapshot: @overview, viewer_id: current_user.id, archived: @group.archived_at?)
    @pending_invitations = @group.group_invitations.pending.where(expires_at: Time.current..).includes(:invited_user) if policy(@group).invite?
  end

  def plan
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :show?
    @dashboard = GroupDashboardQuery.call(group: @group, viewer: current_user)
  end

  def history
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :show?
    page = params.fetch(:page, "1")
    unless /\A[1-9]\d*\z/.match?(page)
      render plain: t("errors.unprocessable_entity"), status: :unprocessable_content
      return
    end
    @history_page = GroupHistoryQuery.page(group: @group, number: page.to_i)
  end

  def settings
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :show?
    pages = invitation_history_pages
    return unless pages

    @memberships = @group.memberships.includes(:user).order(:position, :user_id)
    if policy(@group).invite?
      @sent_pending_page = GroupInvitationHistoryQuery.pending_page(invitations: @group.group_invitations, number: pages.fetch(:pending))
      @sent_terminal_page = GroupInvitationHistoryQuery.terminal_page(invitations: @group.group_invitations, number: pages.fetch(:closed))
      @closed_invitation_history_open = params.key?(:closed_page)
    end
    @membership_deactivation_reasons = membership_deactivation_reasons
    @archive_reason = archive_reason
  end

  def update
    @group = policy_scope(Group).find(params[:id])
    authorize @group

    GroupNameUpdater.call(group_id: @group.id, actor_user_id: current_user.id, name: group_params[:name])
    respond_with_refresh(location: group_path(@group))
  end

  def archive
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :update?
    GroupArchiver.call(group_id: @group.id, actor_user_id: current_user.id)
    respond_with_refresh(location: group_path(@group))
  end

  def restore
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :update?
    GroupRestorer.call(group_id: @group.id, actor_user_id: current_user.id)
    respond_with_refresh(location: group_path(@group))
  end

  private

  def group_params
    params.require(:group).permit(:name)
  end

  def membership_deactivation_reasons
    official_balances = GroupBalanceCalculator.call(@group)
    projected_balances = ProjectedBalanceCalculator.call(official_balances, @group.payments.reported.select(:from_user_id, :to_user_id, :amount_cents))
    last_active_owner = @memberships.count { |membership| membership.owner? && membership.active? } == 1

    @memberships.each_with_object({}) do |membership, reasons|
      next unless membership.active?

      reasons[membership.id] = if !official_balances.fetch(membership.user_id, 0).zero?
        "saldo oficial diferente de zero"
      elsif !projected_balances.fetch(membership.user_id, 0).zero?
        "saldo projetado diferente de zero"
      elsif @group.payments.reported.where(from_user_id: membership.user_id).or(@group.payments.reported.where(to_user_id: membership.user_id)).exists?
        "pagamento pendente envolve membership"
      elsif membership.owner? && last_active_owner
        "último owner ativo não pode sair"
      end
    end
  end

  def archive_reason
    return "grupo não pode ser arquivado" unless %i[empty settled].include?(GroupFinancialStatusResolver.call(@group))

    "grupo possui convite pendente" if @group.group_invitations.pending.where(expires_at: Time.current..).exists?
  end

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
