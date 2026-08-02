class GroupBalanceCalculator
  class UnbalancedLedger < StandardError; end

  def self.call(group)
    new(group).call
  end

  def initialize(group)
    @group = group
  end

  def call
    rows = ApplicationRecord.connection.exec_query(
      sql,
      "GroupBalanceCalculator",
      [ group_id_bind ]
    ).to_a
    ledger_snapshot = rows.first
    balances = rows.filter_map do |row|
      user_id = row["user_id"]
      [ user_id, Integer(row.fetch("balance_cents")) ] if user_id
    end.to_h
    validate_balance_sum!(
      Integer(ledger_snapshot.fetch("ledger_sum_cents")),
      Integer(ledger_snapshot.fetch("financial_state_version"))
    )
    balances
  end

  private

  attr_reader :group

  def group_id_bind
    ActiveRecord::Relation::QueryAttribute.new(
      "group_id",
      group.id,
      Group.type_for_attribute("id")
    )
  end

  def sql
    <<~SQL
      WITH ledger_deltas AS (
        SELECT expenses.paid_by_user_id AS user_id, expenses.amount_cents::numeric AS delta_cents
        FROM expenses
        WHERE expenses.group_id = $1
          AND expenses.voided_at IS NULL

        UNION ALL

        SELECT expense_shares.user_id, -expense_shares.amount_owed_cents::numeric AS delta_cents
        FROM expense_shares
        INNER JOIN expenses ON expenses.id = expense_shares.expense_id
        WHERE expenses.group_id = $1
          AND expenses.voided_at IS NULL

        UNION ALL

        SELECT payments.from_user_id AS user_id, payments.amount_cents::numeric AS delta_cents
        FROM payments
        WHERE payments.group_id = $1
          AND payments.status = 'confirmed'

        UNION ALL

        SELECT payments.to_user_id AS user_id, -payments.amount_cents::numeric AS delta_cents
        FROM payments
        WHERE payments.group_id = $1
          AND payments.status = 'confirmed'
      ),
      ledger_summary AS (
        SELECT COALESCE(SUM(ledger_deltas.delta_cents), 0) AS ledger_sum_cents
        FROM ledger_deltas
      )
      SELECT memberships.user_id::text AS user_id,
             COALESCE(SUM(ledger_deltas.delta_cents), 0) AS balance_cents,
             ledger_summary.ledger_sum_cents,
             groups.financial_state_version
      FROM groups
      CROSS JOIN ledger_summary
      LEFT JOIN memberships ON memberships.group_id = groups.id
      LEFT JOIN ledger_deltas ON ledger_deltas.user_id = memberships.user_id
      WHERE groups.id = $1
      GROUP BY memberships.id,
               memberships.user_id,
               memberships.position,
               ledger_summary.ledger_sum_cents,
               groups.financial_state_version
      ORDER BY memberships.position ASC NULLS LAST, memberships.user_id ASC NULLS LAST
    SQL
  end

  def validate_balance_sum!(ledger_sum_cents, financial_state_version)
    return if ledger_sum_cents.zero?

    error = UnbalancedLedger.new("ledger desequilibrado")
    Rails.error.report(
      error,
      handled: false,
      severity: :error,
      context: { group_id: group.id, financial_state_version: }
    )
    raise error
  end
end
