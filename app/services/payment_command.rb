class PaymentCommand < FinancialCommand
  class InvalidInput < ArgumentError; end
  class Forbidden < StandardError; end
  class NotFound < StandardError; end
  class ArchivedGroup < StandardError; end
  class IdempotencyConflict < StandardError; end
  class StaleFinancialState < StandardError
    attr_reader :financial_state_version, :plan

    def initialize(financial_state_version:, plan:)
      @financial_state_version = financial_state_version
      @plan = plan
      super("estado financeiro desatualizado")
    end
  end
  class SuggestionUnavailable < StandardError; end
  class InvalidTransition < StandardError
    attr_reader :status

    def initialize(status)
      @status = status
      super("transição inválida para pagamento #{status}")
    end
  end

  private

  def resolve_receipt!(key, request_fingerprint)
    receipt = FinancialCommandReceipt.find_by(idempotency_key: key)
    return nil unless receipt

    raise IdempotencyConflict, "chave de idempotência reutilizada" unless receipt.request_fingerprint == request_fingerprint

    receipt.payment
  end

  def perform_idempotent_command(key, request_fingerprint)
    yield
  rescue ActiveRecord::RecordNotUnique => error
    raise unless global_receipt_key_violation?(error)

    resolve_receipt!(key, request_fingerprint) || raise(error)
  end

  def publish(event_name, payment:, actor_user_id:, financial_state_version:)
    payload = { payment_id: payment.id, group_id: payment.group_id, actor_user_id:, financial_state_version: }.freeze
    ActiveRecord.after_all_transactions_commit do
      ActiveSupport::Notifications.instrument(event_name, payload)
    rescue StandardError => error
      Rails.error.report(error, handled: true, severity: :error, context: { payment_id: payment.id, group_id: payment.group_id }, source: event_name)
    end
  end

  def global_receipt_key_violation?(error)
    error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == "index_financial_command_receipts_on_idempotency_key"
  end
end
