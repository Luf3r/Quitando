class SettlementPlanGenerator
  def self.call(group)
    new(group).call
  end

  def initialize(group)
    @group = group
  end

  def call
    DebtSimplifier.new(GroupBalanceCalculator.call(group)).call
  end

  private

  attr_reader :group
end
