class MoneyComponent < ApplicationComponent
  def initialize(cents:, currency_code:)
    @cents = cents
    @formatted_money = MoneyFormatter.call(cents:, currency_code:)
  end
end
