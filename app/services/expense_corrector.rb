require "digest"
require "json"

class ExpenseCorrector
  class InvalidExpense < ArgumentError; end
  class Forbidden < StandardError; end
  class NotFound < StandardError; end
  class ArchivedGroup < StandardError; end
  class StaleFinancialState < StandardError; end
  class IdempotencyConflict < StandardError; end

  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, expense_id:, actor_user_id:, reason:, paid_by_user_id:, description:, occurred_on:, amount_text:, split:, expected_financial_state_version:, idempotency_key:)
    @group_id, @expense_id, @actor_user_id, @reason, @paid_by_user_id, @description, @occurred_on, @amount_text, @split, @expected_financial_state_version, @idempotency_key =
      group_id, expense_id, actor_user_id, reason, paid_by_user_id, description, occurred_on, amount_text, split, expected_financial_state_version, idempotency_key
  end

  def call
    validate_input!
    amount_cents = MoneyParser.parse_cents(amount_text)
    normalized_reason = reason.strip
    request_fingerprint = Digest::SHA256.hexdigest(JSON.generate([ "v1", "expense_correct", group_id, expense_id, actor_user_id, expected_financial_state_version, normalized_reason, paid_by_user_id, description, occurred_on.iso8601, amount_cents, canonical_split ]))

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise Forbidden, "membership ativa obrigatória" unless active_member?(group, actor_user_id)
      original = group.expenses.lock.find_by(id: expense_id) || raise(NotFound, "despesa não encontrada")
      raise Forbidden, "ator não autorizado" unless authorized?(group, original)
      previous = FinancialCommandReceipt.find_by(idempotency_key: idempotency_key)
      if previous
        raise IdempotencyConflict, "chave de idempotência reutilizada" unless previous.request_fingerprint == request_fingerprint
        return previous.expense
      end
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?
      raise StaleFinancialState, "estado financeiro desatualizado" unless group.financial_state_version == expected_financial_state_version
      raise InvalidExpense, "data da despesa é imutável" unless occurred_on == original.occurred_on
      raise InvalidExpense, "despesa anulada" if original.voided_at?

      replacement = ExpenseWriter.call(
        group:,
        created_by_user_id: actor_user_id,
        paid_by_user_id:,
        description:,
        occurred_on:,
        amount_text:,
        split:,
        replaces_expense: original,
        invalid_expense_class: InvalidExpense
      )
      original.update!(voided_at: Time.current, voided_by_user_id: actor_user_id, void_reason: normalized_reason)
      FinancialCommandReceipt.create!(expense: replacement, command_type: :expense_correct, idempotency_key:, request_fingerprint:)
      group.increment!(:financial_state_version)
      schedule_corrected_event(original:, replacement:, group:)
      replacement
    end
  rescue MoneyParser::InvalidAmount => error
    raise InvalidExpense, error.message, cause: nil
  rescue ActiveRecord::RecordNotUnique => error
    raise unless global_receipt_key_violation?(error)

    previous = FinancialCommandReceipt.find_by(idempotency_key: idempotency_key)
    raise error unless previous
    raise IdempotencyConflict, "chave de idempotência reutilizada" unless previous.request_fingerprint == request_fingerprint
    authorize_retry!

    previous.expense
  end

  private

  attr_reader :group_id, :expense_id, :actor_user_id, :reason, :paid_by_user_id, :description, :occurred_on, :amount_text, :split, :expected_financial_state_version, :idempotency_key

  def validate_input!
    identifiers = [ group_id, expense_id, actor_user_id, paid_by_user_id ]
    raise InvalidExpense, "identificadores inválidos" unless identifiers.all? { |id| id.is_a?(String) && UUID_V7_PATTERN.match?(id) }
    raise InvalidExpense, "identificadores inválidos" unless split_user_ids.all? { |id| id.is_a?(String) && UUID_V7_PATTERN.match?(id) }
    raise InvalidExpense, "chave de idempotência inválida" unless idempotency_key.is_a?(String) && UUID_PATTERN.match?(idempotency_key)
    raise InvalidExpense, "versão financeira inválida" unless expected_financial_state_version.is_a?(Integer) && expected_financial_state_version >= 0
    raise InvalidExpense, "motivo inválido" unless reason.is_a?(String) && reason.strip.present?
    raise InvalidExpense, "descrição inválida" unless description.is_a?(String) && description.present?
    raise InvalidExpense, "data inválida" unless occurred_on.is_a?(Date)
  end

  def split_user_ids
    raise InvalidExpense, "divisão inválida" unless split.is_a?(Hash)
    if split[:type] == :equal
      participant_user_ids = split[:participant_user_ids]
      raise InvalidExpense, "divisão inválida" unless participant_user_ids.is_a?(Array) && participant_user_ids.any?

      return participant_user_ids
    end
    if split[:type] == :exact
      shares = split[:shares]
      valid_entries = shares.is_a?(Array) && shares.any? && shares.all? { |share| share.is_a?(Hash) && share.key?(:user_id) && share[:amount_text].is_a?(String) }
      raise InvalidExpense, "divisão inválida" unless valid_entries

      return shares.map { |share| share[:user_id] }
    end

    raise InvalidExpense, "divisão inválida"
  end

  def active_member?(group, user_id)
    Membership.where(group:, user_id:, status: :active).exists?
  end

  def authorized?(group, original)
    actor_user_id == original.created_by_user_id || actor_user_id == original.paid_by_user_id || Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?
  end

  def authorize_retry!
    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise Forbidden, "membership ativa obrigatória" unless active_member?(group, actor_user_id)

      original = group.expenses.lock.find_by(id: expense_id) || raise(NotFound, "despesa não encontrada")
      raise Forbidden, "ator não autorizado" unless authorized?(group, original)
    end
  end

  def canonical_split
    return [ "equal", split.fetch(:participant_user_ids).sort ] if split.is_a?(Hash) && split[:type] == :equal

    [ "exact", split.fetch(:shares).map { |share| [ share.fetch(:user_id), MoneyParser.parse_cents(share.fetch(:amount_text)) ] }.sort ]
  rescue MoneyParser::InvalidAmount
    raise InvalidExpense, "divisão inválida"
  rescue KeyError, NoMethodError
    split
  end

  def schedule_corrected_event(original:, replacement:, group:)
    payload = {
      original_expense_id: original.id,
      replacement_expense_id: replacement.id,
      group_id: group.id,
      actor_user_id:,
      financial_state_version: group.financial_state_version
    }.freeze
    ActiveRecord.after_all_transactions_commit do
      publish_event("quitando.expense.corrected", payload)
      if actor_user_id != replacement.paid_by_user_id
        third_party_payload = { expense_id: replacement.id, group_id: replacement.group_id, recipient_user_id: replacement.paid_by_user_id, created_by_user_id: actor_user_id }.freeze
        publish_event("quitando.expense.created_by_third_party", third_party_payload)
      end
    end
  end

  def publish_event(event_name, payload)
    ActiveSupport::Notifications.instrument(event_name, payload)
  rescue StandardError => error
    Rails.error.report(error, handled: true, severity: :error, context: payload, source: event_name)
  end

  def global_receipt_key_violation?(error)
    error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == "index_financial_command_receipts_on_idempotency_key"
  end
end
