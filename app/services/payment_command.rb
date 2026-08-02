require "digest"
require "json"

class PaymentCommand
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

  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  private

  def validate_persisted_ids!(*ids)
    raise InvalidInput, "identificadores inválidos" unless ids.all? { |id| id.is_a?(String) && UUID_V7_PATTERN.match?(id) }
  end

  def validate_idempotency_key!(key)
    raise InvalidInput, "chave de idempotência inválida" unless key.is_a?(String) && UUID_PATTERN.match?(key)
  end

  def validate_expected_version!(version)
    raise InvalidInput, "versão financeira inválida" unless version.is_a?(Integer) && version >= 0
  end

  def fingerprint(vector)
    Digest::SHA256.hexdigest(JSON.generate(vector))
  end

  def active_member?(group, user_id)
    Membership.where(group:, user_id:, status: :active).exists?
  end

  def resolve_receipt!(key, request_fingerprint)
    receipt = PaymentCommandReceipt.find_by(idempotency_key: key)
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
    error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == "index_payment_command_receipts_on_idempotency_key"
  end
end
