class ExpenseSplitPreview
  class InvalidPreview < ArgumentError; end

  Result = Data.define(:amount_cents, :split_type, :shares)

  def self.call(**)
    new(**).call
  end

  def initialize(amount_text:, split_type:, memberships:, paid_by_user_id:, participant_user_ids: [], shares: [])
    @amount_text = amount_text
    @split_type = split_type
    @memberships = memberships
    @paid_by_user_id = paid_by_user_id
    @participant_user_ids = Array(participant_user_ids)
    normalized_shares = shares.is_a?(Array) ? shares : (shares.respond_to?(:to_h) ? shares.to_h : shares)
    raw_shares = normalized_shares.is_a?(Hash) ? normalized_shares.values : Array(normalized_shares)
    @shares = raw_shares.reject do |share|
      data = share.respond_to?(:to_h) ? share.to_h : share
      data.is_a?(Hash) && (data[:amount_text] || data["amount_text"]).blank?
    end
  end

  def call
    amount_cents = MoneyParser.parse_cents(amount_text)
    computed_shares = split_type == "equal" ? equal_shares(amount_cents) : exact_shares(amount_cents)
    validate_non_payer_obligation!(computed_shares)

    Result.new(
      amount_cents:,
      split_type: split_type,
      shares: computed_shares
    )
  rescue ArgumentError, TypeError => error
    raise InvalidPreview, error.message
  end

  private

  attr_reader :amount_text, :split_type, :memberships, :paid_by_user_id, :participant_user_ids, :shares

  def equal_shares(amount_cents)
    selected = memberships.select { |membership| participant_user_ids.include?(membership.user_id) }
    raise InvalidPreview, "selecione ao menos um participante" unless selected.any?
    raise InvalidPreview, "participante inválido" unless selected.length == participant_user_ids.uniq.length

    EqualSplitCalculator.call(amount_cents:, memberships: selected, paid_by_user_id:).map do |share|
      share.slice(:user_id, :amount_owed_cents)
    end
  end

  def exact_shares(amount_cents)
    raise InvalidPreview, "divisão exata inválida" unless shares.any?

    parsed = shares.map do |share|
      data = share.respond_to?(:to_h) ? share.to_h : share
      raise InvalidPreview, "share inválida" unless data.is_a?(Hash)

      user_id = data[:user_id] || data["user_id"]
      amount = MoneyParser.parse_cents(data[:amount_text] || data["amount_text"])
      raise InvalidPreview, "participante inválido" unless memberships.any? { |membership| membership.user_id == user_id }

      { user_id:, amount_owed_cents: amount }
    end

    raise InvalidPreview, "participantes duplicados" unless parsed.map { |share| share.fetch(:user_id) }.uniq.length == parsed.length
    raise InvalidPreview, "shares devem somar o total" unless parsed.sum { |share| share.fetch(:amount_owed_cents) } == amount_cents

    parsed
  end

  def validate_non_payer_obligation!(computed_shares)
    unless computed_shares.any? { |share| share.fetch(:user_id) != paid_by_user_id }
      raise InvalidPreview, "despesa deve gerar obrigação para não pagador"
    end
  end
end
