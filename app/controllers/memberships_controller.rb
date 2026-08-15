class MembershipsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def deactivate
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    membership = group.memberships.find(params[:id])
    authorize membership, :deactivate?
    MembershipDeactivator.call(group_id: group.id, actor_user_id: current_user.id, user_id: membership.user_id)

    redirect_to groups_path, status: :see_other
  end

  def reactivate
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    membership = group.memberships.find(params[:id])
    authorize membership, :reactivate?
    MembershipReactivator.call(group_id: group.id, actor_user_id: current_user.id, user_id: membership.user_id)

    redirect_to group_path(group), status: :see_other
  end

  def transfer_ownership
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    membership = group.memberships.find(params[:id])
    authorize membership, :transfer_ownership?
    GroupOwnershipTransfer.call(group_id: group.id, actor_user_id: current_user.id, new_owner_user_id: membership.user_id)

    redirect_to group_path(group), status: :see_other
  end

  def order
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :update?
    MembershipOrderer.call(group_id: group.id, actor_user_id: current_user.id, membership_ids: membership_params.fetch(:ids))

    redirect_to group_path(group), status: :see_other
  end

  private

  def membership_params
    params.require(:membership).permit(ids: [])
  end
end
