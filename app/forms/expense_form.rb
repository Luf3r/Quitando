class ExpenseForm
  attr_reader :description, :occurred_on, :amount_text, :paid_by_user_id, :split_type, :participant_user_ids, :shares

  def initialize(description:, occurred_on:, amount_text:, paid_by_user_id:, split_type:, participant_user_ids:, shares: [])
    @description = description
    @occurred_on = occurred_on
    @amount_text = amount_text
    @paid_by_user_id = paid_by_user_id
    @split_type = split_type
    @participant_user_ids = Array(participant_user_ids)
    raw_shares = shares.is_a?(Hash) ? shares.values : Array(shares)
    @shares = raw_shares.map { |share| share.respond_to?(:to_h) ? share.to_h.symbolize_keys : share }
  end

  def valid?
    parsed_date && MoneyParser.parse_cents(amount_text) && description.is_a?(String) && description.strip.present? &&
      paid_by_user_id.present? && valid_split?
  rescue ArgumentError
    false
  end

  def command_attributes
    raise ArgumentError, "formulário inválido" unless valid?

    { description: description.strip, occurred_on: parsed_date, amount_text:, paid_by_user_id:, split: command_split }
  end

  private

  def parsed_date
    @parsed_date ||= Date.iso8601(occurred_on)
  rescue ArgumentError, TypeError
    nil
  end

  def valid_split?
    return participant_user_ids.any? if split_type == "equal"
    return false unless split_type == "exact" && shares.any? && shares.all? { |share| share.is_a?(Hash) && share[:user_id].present? && share[:amount_text].is_a?(String) }

    shares.sum { |share| MoneyParser.parse_cents(share[:amount_text]) } == MoneyParser.parse_cents(amount_text)
  end

  def command_split
    split_type == "equal" ? { type: :equal, participant_user_ids: } : { type: :exact, shares: }
  end
end
