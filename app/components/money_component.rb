class MoneyComponent < ApplicationComponent
  def initialize(cents:, currency_code:)
    @formatted_money = MoneyFormatter.call(cents:, currency_code:)
  end
end
