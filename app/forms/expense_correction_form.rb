class ExpenseCorrectionForm < ExpenseForm
  attr_reader :reason, :expected_financial_state_version, :idempotency_key

  def initialize(reason: nil, expected_financial_state_version: nil, idempotency_key: nil, **expense_attributes)
    @reason = reason
    @expected_financial_state_version = expected_financial_state_version
    @idempotency_key = idempotency_key
    super(**expense_attributes)
  end

  def valid?
    super && reason.is_a?(String) && reason.strip.present? && parsed_financial_state_version && idempotency_key.is_a?(String) && idempotency_key.present?
  end

  def command_attributes
    super.merge(
      reason: reason.strip,
      expected_financial_state_version: parsed_financial_state_version,
      idempotency_key:
    )
  end

  private

  def parsed_financial_state_version
    return @parsed_financial_state_version if defined?(@parsed_financial_state_version)

    @parsed_financial_state_version = Integer(expected_financial_state_version, 10)
    @parsed_financial_state_version = nil if @parsed_financial_state_version.negative?
    @parsed_financial_state_version
  rescue ArgumentError, TypeError
    @parsed_financial_state_version = nil
  end
end
