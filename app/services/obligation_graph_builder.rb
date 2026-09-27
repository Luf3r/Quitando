class ObligationGraphBuilder
  Edge = Data.define(:from_user_id, :to_user_id, :amount_cents)
  Result = Data.define(:expense_obligations, :bilateral_obligations)

  def self.call(group)
    new(group).call
  end

  def initialize(group)
    @group = group
  end

  def call
    amounts_by_pair = Hash.new(0)
    active_expenses.each do |expense|
      expense.expense_shares.each do |share|
        next if share.user_id == expense.paid_by_user_id

        amounts_by_pair[[ share.user_id, expense.paid_by_user_id ]] += share.amount_owed_cents
      end
    end
    obligations = amounts_by_pair.sort.map do |(from_user_id, to_user_id), amount_cents|
      Edge.new(from_user_id:, to_user_id:, amount_cents:)
    end

    Result.new(
      expense_obligations: obligations,
      bilateral_obligations: bilateral_obligations(amounts_by_pair)
    )
  end

  private

  attr_reader :group

  def active_expenses
    group.expenses.where(voided_at: nil).includes(:expense_shares)
  end

  def bilateral_obligations(amounts_by_pair)
    amounts_by_pair.keys.map(&:sort).uniq.sort.filter_map do |first_user_id, second_user_id|
      difference = amounts_by_pair[[ first_user_id, second_user_id ]] -
        amounts_by_pair[[ second_user_id, first_user_id ]]
      next if difference.zero?

      if difference.positive?
        Edge.new(from_user_id: first_user_id, to_user_id: second_user_id, amount_cents: difference)
      else
        Edge.new(from_user_id: second_user_id, to_user_id: first_user_id, amount_cents: -difference)
      end
    end.sort_by { |edge| [ edge.from_user_id, edge.to_user_id ] }
  end
end
