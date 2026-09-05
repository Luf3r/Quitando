class ExpensesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
  rescue_from ExpenseCreator::InvalidExpense, with: :render_invalid_expense
  rescue_from ExpenseCorrector::InvalidExpense, ExpenseCorrector::ArchivedGroup, ExpenseCorrector::StaleFinancialState,
              ExpenseCorrector::IdempotencyConflict, with: :render_correction_error

  def new
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :create_expense?
    @dashboard = GroupDashboardQuery.call(group: @group, viewer: current_user)
    @expense_form = ExpenseForm.new(paid_by_user_id: current_user.id)

    render_dialog_or_page(:new)
  end

  def create
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :create_expense?
    form = ExpenseForm.new(**expense_params.to_h.symbolize_keys)
    raise ExpenseCreator::InvalidExpense, "despesa inválida" unless form.valid?

    ExpenseCreator.call(**form.command_attributes.merge(group_id: group.id, created_by_user_id: current_user.id))
    respond_to do |format|
      format.html { redirect_to group_path(group), status: :see_other }
      format.turbo_stream { render turbo_stream: successful_dialog_stream }
    end
  end

  def preview
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :create_expense?
    @submitted_expense = expense_params.to_h
    @expense_form = ExpenseForm.new(**@submitted_expense.symbolize_keys)
    raise ExpenseSplitPreview::InvalidPreview, "revise os campos obrigatórios da despesa" unless @expense_form.valid?

    @preview = ExpenseSplitPreview.call(
      amount_text: expense_params[:amount_text],
      split_type: expense_params[:split_type],
      memberships: @group.memberships.active.order(:position, :user_id).to_a,
      paid_by_user_id: expense_params[:paid_by_user_id],
      participant_user_ids: expense_params[:participant_user_ids],
      shares: expense_params[:shares]
    )

    render :preview, status: :ok
  rescue ExpenseSplitPreview::InvalidPreview => error
    @preview_error = error.message
    render :preview, status: :unprocessable_content
  end

  def show
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    load_expense_detail(group)
  end

  def correction
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :create_expense?
    load_expense_detail(@group)
    authorize @expense, :correct?
    @correction_form = ExpenseCorrectionForm.new
    @current_financial_state_version = @group.financial_state_version

    render_dialog_or_page(:correction)
  end

  def correction_preview
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :create_expense?
    load_expense_detail(@group)
    authorize @expense, :correct?
    @submitted_correction = correction_params.to_h
    @correction_form = ExpenseCorrectionForm.new(**@submitted_correction.symbolize_keys.merge(occurred_on: @expense.occurred_on))
    raise ExpenseSplitPreview::InvalidPreview, "revise os campos obrigatórios da correção" unless @correction_form.valid?

    @preview = ExpenseSplitPreview.call(
      amount_text: correction_params[:amount_text],
      split_type: correction_params[:split_type],
      memberships: @group.memberships.active.order(:position, :user_id).to_a,
      paid_by_user_id: correction_params[:paid_by_user_id],
      participant_user_ids: correction_params[:participant_user_ids],
      shares: correction_params[:shares]
    )

    render :correction_preview
  rescue ExpenseSplitPreview::InvalidPreview => error
    @preview_error = error.message
    render :correction_preview, status: :unprocessable_content
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
    respond_to do |format|
      format.html { redirect_to group_expense_path(group, replacement), status: :see_other }
      format.turbo_stream { render turbo_stream: successful_dialog_stream }
    end
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
    if turbo_frame_request? && request.headers["Turbo-Frame"] == "expense_preview"
      @preview_error = error.message
      render :preview, formats: :html, status: :unprocessable_entity, layout: false
    elsif turbo_frame_request?
      render :new_dialog, formats: :html, status: :unprocessable_entity, layout: false
    else
      render :new, status: :unprocessable_entity
    end
  end

  def render_correction_error(error)
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    load_expense_detail(group)
    @dashboard = GroupDashboardQuery.call(group:, viewer: current_user)
    @current_financial_state_version = group.financial_state_version
    flash.now[:alert] = error.message
    if turbo_frame_request? && request.headers["Turbo-Frame"] == "correction_preview"
      @group = group
      @preview_error = error.message
      render :correction_preview, formats: :html, status: Http::DomainErrorMapper.call(error).status, layout: false
    elsif turbo_frame_request?
      @group = group
      render :correction_dialog, formats: :html, status: Http::DomainErrorMapper.call(error).status, layout: false
    else
      @group = group
      render :correction, status: Http::DomainErrorMapper.call(error).status
    end
  end

  def render_dialog_or_page(template)
    if turbo_frame_request?
      render "#{template}_dialog", layout: false
    else
      render template
    end
  end

  def successful_dialog_stream
    turbo_stream.update("group_dialog", "") + %(<turbo-stream action="refresh"></turbo-stream>).html_safe
  end

  def load_expense_detail(group)
    @expense = group.expenses.includes(:paid_by_user, :created_by_user, :voided_by_user, expense_shares: :user, expense_description_revisions: :actor_user, replaces_expense: [], replacement_expenses: []).find(params[:id])
  end
end
