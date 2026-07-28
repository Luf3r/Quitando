require "rails_helper"
require "timeout"

RSpec.describe ExpenseCreator, :non_transactional do
  self.use_transactional_tests = false

  it "serializa duas criações em sessões PostgreSQL distintas sob contenção real do grupo" do
    group = create(:group)
    payer = create(:user)
    participant = create(:user)
    created_user_ids = [ payer.id, participant.id ]
    [ payer, participant ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    lock_acquired = Queue.new
    release_lock = Queue.new
    second_session_started = Queue.new
    results = Queue.new
    backend_pids = Queue.new

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        connection.transaction do
          connection.execute("SET LOCAL lock_timeout = '5s'")
          Group.lock.find(group.id)
          lock_acquired << true
          release_lock.pop
          results << create_expense(group:, payer:, participant:)
        end
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(10) { lock_acquired.pop }
    first_backend_pid = Timeout.timeout(10) { backend_pids.pop }

    second_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '5s'")
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        second_session_started << true
        results << create_expense(group:, payer:, participant:)
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(10) { second_session_started.pop }
    second_backend_pid = Timeout.timeout(10) { backend_pids.pop }
    expect(second_backend_pid).not_to eq(first_backend_pid)

    Timeout.timeout(5) do
      loop do
        wait_event_type = ApplicationRecord.connection.select_value(
          ApplicationRecord.sanitize_sql_array(
            [ "SELECT wait_event_type FROM pg_stat_activity WHERE pid = ?", second_backend_pid ]
          )
        )
        break if wait_event_type == "Lock"

        sleep 0.02
      end
    end

    release_lock << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    values = 2.times.map { Timeout.timeout(10) { results.pop } }

    expect(values).to all(be_a(Expense))
    expect(group.reload.financial_state_version).to eq(2)
    expect(group.expenses.count).to eq(2)
    expect(group.expenses.joins(:expense_shares).group(:id).count.values).to contain_exactly(2, 2)
  ensure
    primary_error = $!
    begin
      release_lock << true if release_lock
      threads = [ first_thread, second_thread ].compact
      threads.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { threads.each(&:join) }

      ApplicationRecord.transaction do
        ApplicationRecord.connection.execute("SET LOCAL lock_timeout = '5s'")
        if group&.persisted?
          expense_ids = Expense.where(group_id: group.id).pluck(:id)
          ExpenseShare.where(expense_id: expense_ids).delete_all
          Expense.where(id: expense_ids).delete_all
          Membership.where(group_id: group.id).delete_all
          Group.where(id: group.id).delete_all
        end
        User.where(id: created_user_ids).delete_all if created_user_ids
      end
    rescue StandardError => cleanup_error
      warn "expense concurrency cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  def create_expense(group:, payer:, participant:)
    described_class.call(
      group_id: group.id,
      created_by_user_id: payer.id,
      paid_by_user_id: payer.id,
      description: "Teste concorrente",
      occurred_on: Date.new(2026, 7, 27),
      amount_text: "2,00",
      split: { type: :equal, participant_user_ids: [ payer.id, participant.id ] }
    )
  end
end
