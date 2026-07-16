class MoneyParser
  class InvalidAmount < ArgumentError; end

  DECIMAL_PT_BR = /\A(?:0|[1-9]\d{0,2}(?:\.\d{3})*|[1-9]\d*)(?:,\d{2})?\z/

  def self.parse_cents(value)
    raise InvalidAmount, "valor monetário deve ser texto" unless value.is_a?(String)

    text = value
    raise InvalidAmount, "valor monetário inválido" unless DECIMAL_PT_BR.match?(text)

    whole, fraction = text.split(",", 2)
    cents = (whole.delete(".").to_i * 100) + fraction.to_s.ljust(2, "0").to_i
    raise InvalidAmount, "valor deve ser maior que zero" unless cents.positive?

    cents
  end
end
