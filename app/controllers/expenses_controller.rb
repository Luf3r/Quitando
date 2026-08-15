class ExpensesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
  rescue_from ExpenseCreator::InvalidExpense, with: :render_invalid_expense
  rescue_from ExpenseCorrector::InvalidExpense, ExpenseCorrector::ArchivedGroup, ExpenseCorrector::StaleFinancialState,
              ExpenseCorrector::IdempotencyConflict, with: :render_correction_error

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
    load_expense_detail(group)
  end

  def update_description
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    expense = group.expenses.find(params[:id])
    authorize expense, :update_description?
    ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: current_user.id, description: expense_params[:description])
    redirect_to group_expense_path(group, expense), status: :see_other
  end

  def correct
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :create_expense?
    expense = group.expenses.find(params[:id])
    authorize expense, :correct?
    @correction_form = ExpenseCorrectionForm.new(**correction_params.to_h.symbolize_keys.merge(occurred_on: expense.occurred_on))
    raise ExpenseCorrector::InvalidExpense, "correção inválida" unless @correction_form.valid?

    replacement = ExpenseCorrector.call(**@correction_form.command_attributes.merge(group_id: group.id, expense_id: expense.id, actor_user_id: current_user.id))
    redirect_to group_expense_path(group, replacement), status: :see_other
  end

  private

  def expense_params
    params.require(:expense).permit(:description, :occurred_on, :amount_text, :paid_by_user_id, :split_type, participant_user_ids: [], shares: [ :user_id, :amount_text ])
  end

  def correction_params
    params.require(:correction).permit(
      :reason, :description, :amount_text, :paid_by_user_id, :split_type, :expected_financial_state_version, :idempotency_key,
      participant_user_ids: [], shares: [ :user_id, :amount_text ]
    )
  end

  def render_invalid_expense(error)
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :create_expense?
    @dashboard = GroupDashboardQuery.call(group: @group, viewer: current_user)
    @history_entries = GroupHistoryQuery.call(group: @group)
    @pending_invitations = @group.group_invitations.pending.where(expires_at: Time.current..).includes(:invited_user) if policy(@group).invite?
    @expense_form = ExpenseForm.new(**expense_params.to_h.symbolize_keys)
    flash.now[:alert] = error.message
    render "groups/show", status: :unprocessable_entity
  end

  def render_correction_error(error)
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    load_expense_detail(group)
    @dashboard = GroupDashboardQuery.call(group:, viewer: current_user)
    @current_financial_state_version = group.financial_state_version
    flash.now[:alert] = error.message
    render :show, status: Http::DomainErrorMapper.call(error).status
  end

  def load_expense_detail(group)
    @expense = group.expenses.includes(:paid_by_user, :created_by_user, :expense_shares, :replaces_expense, :replacement_expenses).find(params[:id])
  end
end
