class PaymentsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
  rescue_from PaymentCommand::StaleFinancialState, PaymentCommand::IdempotencyConflict, with: :render_payment_conflict

  def create
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    payment = PaymentReporter.call(**payment_params.to_h.symbolize_keys.merge(
      group_id: group.id,
      actor_user_id: current_user.id,
      expected_financial_state_version: financial_state_version
    ))

    redirect_to group_payment_path(group, payment), status: :see_other
  end

  def show
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    @payment = group.payments.includes(:from_user, :to_user, :reported_by_user).find(params[:id])
    authorize @payment, :show?
  end

  def confirm
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    payment = group.payments.find(params[:id])
    authorize payment, :confirm?
    PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: current_user.id, idempotency_key: payment_params[:idempotency_key])

    redirect_to group_payment_path(group, payment), status: :see_other
  end

  def cancel
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    payment = group.payments.find(params[:id])
    authorize payment, :cancel?
    PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: current_user.id, reason: payment_params[:reason], idempotency_key: payment_params[:idempotency_key])

    redirect_to group_payment_path(group, payment), status: :see_other
  end

  private

  def payment_params
    params.require(:payment).permit(:from_user_id, :to_user_id, :amount_text, :expected_financial_state_version, :idempotency_key, :reason)
  end

  def financial_state_version
    Integer(payment_params.fetch(:expected_financial_state_version), 10).tap do |version|
      raise PaymentCommand::InvalidInput, "versão financeira inválida" if version.negative?
    end
  rescue ArgumentError, TypeError
    raise PaymentCommand::InvalidInput, "versão financeira inválida"
  end

  def render_payment_conflict(error)
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :show?
    @dashboard = GroupDashboardQuery.call(group: @group, viewer: current_user)
    @history_entries = GroupHistoryQuery.call(group: @group)
    @pending_invitations = @group.group_invitations.pending.includes(:invited_user) if policy(@group).invite?
    flash.now[:alert] = error.message
    render "groups/show", status: Http::DomainErrorMapper.call(error).status
  end
end
