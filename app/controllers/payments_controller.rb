class PaymentsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
  rescue_from PaymentCommand::StaleFinancialState, PaymentCommand::IdempotencyConflict, with: :render_payment_conflict
  rescue_from PaymentCommand::InvalidInput, PaymentCommand::SuggestionUnavailable, with: :render_payment_error

  def new
    validate_to_user_id!
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :show?
    @dashboard = GroupDashboardQuery.call(group: @group, viewer: current_user)
    @suggestion = @dashboard.settlement_plan.find { |transfer| transfer.from_user_id == current_user.id && transfer.to_user_id == to_user_id }
    raise PaymentCommand::SuggestionUnavailable, "sugestão indisponível" unless @suggestion

    @payment_form = default_payment_form(@suggestion)
    render_dialog_or_page(:new)
  end

  def create
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    payment = PaymentReporter.call(**payment_params.to_h.symbolize_keys.merge(
      group_id: group.id,
      actor_user_id: current_user.id,
      from_user_id: current_user.id,
      expected_financial_state_version: financial_state_version
    ))

    respond_to do |format|
      format.html { redirect_to group_payment_path(group, payment), status: :see_other }
      format.turbo_stream { render turbo_stream: successful_dialog_stream("Pagamento declarado e aguardando confirmação.") }
    end
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

    respond_to do |format|
      format.html { redirect_to group_payment_path(group, payment), status: :see_other }
      format.turbo_stream { render turbo_stream: successful_dialog_stream("Pagamento confirmado.") }
    end
  end

  def cancel
    group = policy_scope(Group).find(params[:group_id])
    authorize group, :show?
    payment = group.payments.find(params[:id])
    authorize payment, :cancel?
    PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: current_user.id, reason: payment_params[:reason], idempotency_key: payment_params[:idempotency_key])

    respond_to do |format|
      format.html { redirect_to group_payment_path(group, payment), status: :see_other }
      format.turbo_stream { render turbo_stream: successful_dialog_stream("Declaração de pagamento cancelada.") }
    end
  end

  private

  def payment_params
    params.require(:payment).permit(:from_user_id, :to_user_id, :amount_text, :expected_financial_state_version, :idempotency_key, :reason)
  end

  def to_user_id
    @to_user_id ||= params[:to_user_id]
  end

  def validate_to_user_id!
    raise PaymentCommand::InvalidInput, "destino inválido" unless CanonicalUuidV7RouteConstraint::UUID_V7_PATTERN.match?(to_user_id)
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
    @payment_conflict = payment_params.to_h.symbolize_keys.merge(from_user_id: current_user.id)
    @payment_form = @payment_conflict.merge(expected_financial_state_version: @group.financial_state_version)
    flash.now[:alert] = error.message
    render_dialog_or_page(:new, status: Http::DomainErrorMapper.call(error).status)
  end

  def render_payment_error(error)
    @group = policy_scope(Group).find(params[:group_id])
    authorize @group, :show?
    @payment_error = error.message
    render_dialog_or_page(:new, status: Http::DomainErrorMapper.call(error).status)
  end

  def render_dialog_or_page(template, status: :ok)
    if turbo_frame_request?
      render "#{template}_dialog", formats: :html, layout: false, status:
    else
      render template, status:
    end
  end

  def default_payment_form(suggestion)
    {
      from_user_id: current_user.id,
      to_user_id: suggestion.to_user_id,
      amount_text: MoneyFormatter.call(cents: suggestion.amount_cents, currency_code: @group.currency_code).delete_prefix("R$ "),
      expected_financial_state_version: @group.financial_state_version,
      idempotency_key: SecureRandom.uuid
    }
  end

  def successful_dialog_stream(message)
    notice = view_context.content_tag(:p, message, class: "rounded bg-emerald-50 p-3 text-emerald-900")
    turbo_stream.update("group_remote_notice", notice) +
      turbo_stream.update("group_dialog", "") +
      %(<turbo-stream action="refresh"></turbo-stream>).html_safe
  end
end
