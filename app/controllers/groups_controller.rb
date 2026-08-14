class GroupsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    authorize Group, :index?
    @groups = policy_scope(Group)
  end

  def create
    authorize Group, :create?
    GroupCreator.call(owner_user_id: current_user.id, name: group_params[:name])

    redirect_to groups_path, status: :see_other
  end

  def show
    @group = policy_scope(Group).find(params[:id])
    authorize @group
    @pending_invitations = @group.group_invitations.pending.includes(:invited_user) if policy(@group).invite?
  end

  def update
    @group = policy_scope(Group).find(params[:id])
    authorize @group

    GroupNameUpdater.call(group_id: @group.id, actor_user_id: current_user.id, name: group_params[:name])
    redirect_to group_path(@group), status: :see_other
  end

  private

  def group_params
    params.require(:group).permit(:name)
  end
end
