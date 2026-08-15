class ExpensesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
  rescue_from ExpenseCreator::InvalidExpense, with: :render_invalid_expense

  def create
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :create_expense?
    form = ExpenseForm.new(**expense_params.to_h.symbolize_keys)
    raise ExpenseCreator::InvalidExpense, "despesa inválida" unless form.valid?

    ExpenseCreator.call(**form.command_attributes.merge(group_id: group.id, created_by_user_id: current_user.id))
    redirect_to group_path(group), status: :see_other
  end

  def show
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    @expense = group.expenses.includes(:paid_by_user, :created_by_user, :expense_shares).find(params[:id])
  end

  private

  def expense_params
    params.require(:expense).permit(:description, :occurred_on, :amount_text, :paid_by_user_id, :split_type, participant_user_ids: [], shares: [ :user_id, :amount_text ])
  end

  def render_invalid_expense(error)
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :create_expense?
    @dashboard = GroupDashboardQuery.call(group: @group, viewer: current_user)
    @history_entries = GroupHistoryQuery.call(group: @group)
    @pending_invitations = @group.group_invitations.pending.includes(:invited_user) if policy(@group).invite?
    @expense_form = ExpenseForm.new(**expense_params.to_h.symbolize_keys)
    flash.now[:alert] = error.message
    render "groups/show", status: :unprocessable_entity
  end
end
