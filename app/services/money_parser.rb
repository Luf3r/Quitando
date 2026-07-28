class MoneyParser
  class InvalidAmount < ArgumentError; end

  DECIMAL_PT_BR = /\A(?:0|[1-9]\d{0,2}(?:\.\d{3})*|[1-9]\d*)(?:,\d{2})?\z/
  BIGINT_MAX = 9_223_372_036_854_775_807
  BIGINT_MAX_TEXT = BIGINT_MAX.to_s

  def self.parse_cents(value)
    raise InvalidAmount, "valor monetário deve ser texto" unless value.is_a?(String)

    text = value
    raise InvalidAmount, "valor monetário inválido" unless DECIMAL_PT_BR.match?(text)

    whole, fraction = text.split(",", 2)
    whole_digits = whole.delete(".")
    fraction_digits = fraction.to_s.ljust(2, "0")
    cents_text = "#{whole_digits}#{fraction_digits}"
    if cents_text.length > BIGINT_MAX_TEXT.length ||
        (cents_text.length == BIGINT_MAX_TEXT.length && (cents_text <=> BIGINT_MAX_TEXT).positive?)
      raise InvalidAmount, "valor excede o limite de bigint"
    end

    cents = (whole_digits.to_i * 100) + fraction_digits.to_i
    raise InvalidAmount, "valor deve ser maior que zero" unless cents.positive?
    raise InvalidAmount, "valor excede o limite de bigint" if cents > BIGINT_MAX

    cents
  end
end
