class ProjectedBalanceCalculator
  def self.call(official_balances, reported_payments)
    projected_balances = official_balances.dup

    reported_payments.each do |payment|
      projected_balances[payment.from_user_id] += payment.amount_cents
      projected_balances[payment.to_user_id] -= payment.amount_cents
    end

    projected_balances
  end
end
