class ProjectedBalanceCalculator
  def self.call(official_balances, reported_payments)
    projected_balances = official_balances.dup

    reported_payments.each do |payment|
      from_balance = projected_balances.fetch(payment.from_user_id)
      to_balance = projected_balances.fetch(payment.to_user_id)

      projected_balances[payment.from_user_id] = from_balance + payment.amount_cents
      projected_balances[payment.to_user_id] = to_balance - payment.amount_cents
    end

    projected_balances
  end
end
