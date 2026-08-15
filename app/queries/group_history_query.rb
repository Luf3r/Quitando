class GroupHistoryQuery
  Entry = Data.define(:kind, :record, :occurred_at, :cycles)

  def self.call(group:)
    entries = group.expenses.includes(:replaces_expense, :replacement_expenses).map do |expense|
      cycles = []
      cycles << :voided if expense.voided_at?
      cycles << :replacement if expense.replaces_expense_id?
      cycles << :recorded if cycles.empty?
      Entry.new(kind: :expense, record: expense, occurred_at: expense.created_at, cycles:)
    end
    entries.concat(group.payments.map { |payment| Entry.new(kind: :payment, record: payment, occurred_at: payment.created_at, cycles: [ payment.status.to_sym ]) })
    entries.sort_by(&:occurred_at).reverse
  end
end
