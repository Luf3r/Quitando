class GroupFinancialStatusResolver
  def self.call(group)
    new(group).call
  end

  def initialize(group)
    @group = group
  end

  def call
    reported_payment = reported_payment?

    return :empty unless financial_activity?(reported_payment:)
    balances = official_balances

    return :awaiting_confirmation if reported_payment
    return :settled if balances.values.all?(&:zero?)

    :open
  end

  private

  attr_reader :group

  def financial_activity?(reported_payment:)
    group.expenses.where(voided_at: nil).exists? ||
      reported_payment ||
      group.payments.confirmed.exists?
  end

  def reported_payment?
    group.payments.reported.exists?
  end

  def official_balances
    GroupBalanceCalculator.call(group)
  end
end
