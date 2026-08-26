class GroupHistoryQuery
  Entry = Data.define(:kind, :record, :occurred_at, :cycles)
  Page = Data.define(:entries, :number, :total_pages, :total_facts)
  PER_PAGE = 25

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

  def self.page(group:, number:)
    entries = call(group:)
    total_facts = entries.length
    total_pages = [ (total_facts + PER_PAGE - 1) / PER_PAGE, 1 ].max
    offset = (number - 1) * PER_PAGE

    Page.new(entries: entries.slice(offset, PER_PAGE) || [], number:, total_pages:, total_facts:)
  end
end
