class SettlementPlanGenerator
  def self.call(group)
    new(group).call
  end

  def initialize(group)
    @group = group
  end

  def call
    official_balances = GroupBalanceCalculator.call(group)
    projected_balances = ProjectedBalanceCalculator.call(official_balances, group.payments.reported)

    DebtSimplifier.new(projected_balances).call
  end

  private

  attr_reader :group
end
