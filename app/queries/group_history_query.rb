class GroupHistoryQuery
  Entry = Data.define(:kind, :record, :occurred_at)

  def self.call(group:)
    entries = group.expenses.map { |expense| Entry.new(kind: :expense, record: expense, occurred_at: expense.created_at) }
    entries.concat(group.payments.map { |payment| Entry.new(kind: :payment, record: payment, occurred_at: payment.created_at) })
    entries.sort_by(&:occurred_at).reverse
  end
end
