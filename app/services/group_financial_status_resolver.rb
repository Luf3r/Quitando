class GroupFinancialStatusResolver
  def self.call(group)
    new(group).call
  end

  def initialize(group)
    @group = group
  end

  def call
    return :empty unless financial_activity?

    return :settled if official_balances.values.all?(&:zero?)

    :open
  end

  private

  attr_reader :group

  def financial_activity?
    group.expenses.where(voided_at: nil).exists? ||
      group.payments.where(status: %w[reported confirmed]).exists?
  end

  def official_balances
    GroupBalanceCalculator.call(group)
  end
end
