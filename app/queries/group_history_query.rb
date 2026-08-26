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
    total_facts = fact_count(group)
    total_pages = [ (total_facts + PER_PAGE - 1) / PER_PAGE, 1 ].max
    offset = (number - 1) * PER_PAGE
    rows = ApplicationRecord.connection.select_all(
      ApplicationRecord.sanitize_sql_array([ <<~SQL, group.id, group.id, PER_PAGE, offset ])
        SELECT fact_type, id, occurred_at
        FROM (
          SELECT 'expense' AS fact_type, id, created_at AS occurred_at FROM expenses WHERE group_id = ?
          UNION ALL
          SELECT 'payment' AS fact_type, id, created_at AS occurred_at FROM payments WHERE group_id = ?
        ) facts
        ORDER BY occurred_at DESC, id DESC
        LIMIT ? OFFSET ?
      SQL
    )
    expense_ids = rows.filter_map { |row| row.fetch("id") if row.fetch("fact_type") == "expense" }
    payment_ids = rows.filter_map { |row| row.fetch("id") if row.fetch("fact_type") == "payment" }
    expenses = group.expenses.includes(:replaces_expense, :replacement_expenses).where(id: expense_ids).index_by(&:id)
    payments = group.payments.includes(:from_user, :to_user, :reported_by_user, :confirmed_by_user, :cancelled_by_user).where(id: payment_ids).index_by(&:id)
    entries = rows.map do |row|
      if row.fetch("fact_type") == "expense"
        expense_entry(expenses.fetch(row.fetch("id")))
      else
        payment = payments.fetch(row.fetch("id"))
        Entry.new(kind: :payment, record: payment, occurred_at: payment.created_at, cycles: [ payment.status.to_sym ])
      end
    end

    Page.new(entries:, number:, total_pages:, total_facts:)
  end

  def self.fact_count(group)
    ApplicationRecord.connection.select_value(
      ApplicationRecord.sanitize_sql_array([ <<~SQL, group.id, group.id ])
        SELECT COUNT(*) FROM (
          SELECT id FROM expenses WHERE group_id = ?
          UNION ALL
          SELECT id FROM payments WHERE group_id = ?
        ) facts
      SQL
    ).to_i
  end

  def self.expense_entry(expense)
    cycles = []
    cycles << :voided if expense.voided_at?
    cycles << :replacement if expense.replaces_expense_id?
    cycles << :recorded if cycles.empty?
    Entry.new(kind: :expense, record: expense, occurred_at: expense.created_at, cycles:)
  end
  private_class_method :fact_count, :expense_entry
end
