class GroupsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    authorize Group, :index?
    @group_cards = GroupListQuery.call(groups: policy_scope(Group), viewer: current_user)
    visible_invitations = policy_scope(GroupInvitation)
    visible_invitations.where(expires_at: ..Time.current).find_each do |invitation|
      GroupInvitationExpirer.call(invitation_id: invitation.id)
    end
    @invitations = visible_invitations.includes(:group, :invited_by_user).to_a
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
    @history_entries = GroupHistoryQuery.call(group: @group)
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
    @memberships = @group.memberships.includes(:user).order(:position, :user_id)
    @pending_invitations = @group.group_invitations.pending.where(expires_at: Time.current..).includes(:invited_user) if policy(@group).invite?
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
end
