class MoneyFormatter
  def self.call(cents:, currency_code:)
    raise ArgumentError, "moeda não suportada" unless currency_code == "BRL"
    raise ArgumentError, "centavos inválidos" unless cents.is_a?(Integer)

    sign = cents.negative? ? "-" : ""
    units, fractional = cents.abs.divmod(100)
    formatted_fractional = fractional.to_s.rjust(2, "0")

    "#{sign}R$ #{units},#{formatted_fractional}"
  end
end
