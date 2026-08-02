require "rails_helper"
require "timeout"

RSpec.describe PaymentReporter, :non_transactional do
  self.use_transactional_tests = false

  it "does not reserve the same suggestion twice across PostgreSQL sessions" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    created_user_ids = [ receiver.id, sender.id ]
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 2), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })
    expected_version = group.reload.financial_state_version
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
          results << report(group:, sender:, receiver:, expected_version:)
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
        results << report(group:, sender:, receiver:, expected_version:)
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(10) { second_session_started.pop }
    second_backend_pid = Timeout.timeout(10) { backend_pids.pop }
    expect(second_backend_pid).not_to eq(first_backend_pid)

    expect(wait_for_lock(second_backend_pid)).to eq("Lock")

    release_lock << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values.count { |value| value.is_a?(Payment) }).to eq(1)
    expect(values.grep(PaymentCommand::StaleFinancialState).length).to eq(1)
    expect(group.payments.reported.sum(:amount_cents)).to eq(300)
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
          payment_ids = Payment.where(group_id: group.id).pluck(:id)
          expense_ids = Expense.where(group_id: group.id).pluck(:id)
          delete_payment_command_receipts_for_cleanup!(PaymentCommandReceipt.where(payment_id: payment_ids))
          Payment.where(id: payment_ids).delete_all
          ExpenseShare.where(expense_id: expense_ids).delete_all
          Expense.where(id: expense_ids).delete_all
          Membership.where(group_id: group.id).delete_all
          Group.where(id: group.id).delete_all
        end
        User.where(id: created_user_ids).delete_all if created_user_ids
      end
    rescue StandardError => cleanup_error
      warn "payment reporter concurrency cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  it "translates a global idempotency-key collision across groups to a domain conflict" do
    receiver = create(:user)
    sender = create(:user)
    groups = 2.times.map do
      group = create(:group)
      [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
      ExpenseCreator.call(group_id: group.id, created_by_user_id: receiver.id, paid_by_user_id: receiver.id, description: "Jantar", occurred_on: Date.new(2026, 8, 2), amount_text: "6,00", split: { type: :equal, participant_user_ids: [ receiver.id, sender.id ] })
      group
    end
    key = SecureRandom.uuid
    expected_versions = groups.to_h { |group| [ group.id, group.reload.financial_state_version ] }
    holder_ready = Queue.new
    release_holder = Queue.new
    contender_started = Queue.new
    results = Queue.new
    backend_pids = Queue.new
    first_group, second_group = groups

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        result = nil
        connection.transaction do
          connection.execute("SET LOCAL lock_timeout = '5s'")
          result = described_class.call(group_id: first_group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "3,00", expected_financial_state_version: expected_versions.fetch(first_group.id), idempotency_key: key)
          holder_ready << true
          release_holder.pop
        end
        results << result
      end
    rescue StandardError => error
      holder_ready << error
      results << error
    end

    first_backend_pid = Timeout.timeout(5) { backend_pids.pop }
    holder_state = Timeout.timeout(5) { holder_ready.pop }
    raise holder_state if holder_state.is_a?(StandardError)

    second_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '5s'")
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        contender_started << true
        results << described_class.call(group_id: second_group.id, actor_user_id: sender.id, from_user_id: sender.id, to_user_id: receiver.id, amount_text: "3,00", expected_financial_state_version: expected_versions.fetch(second_group.id), idempotency_key: key)
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(5) { contender_started.pop }
    second_backend_pid = Timeout.timeout(5) { backend_pids.pop }
    expect(second_backend_pid).not_to eq(first_backend_pid)
    expect(wait_for_lock(second_backend_pid)).to eq("Lock")

    release_holder << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }
    expect(values.count { |value| value.is_a?(Payment) }).to eq(1)
    expect(values.grep(PaymentCommand::IdempotencyConflict).length).to eq(1)
  ensure
    primary_error = $!
    begin
      release_holder << true if release_holder
      threads = [ first_thread, second_thread ].compact
      threads.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { threads.each(&:join) }
      groups&.each do |group|
        payment_ids = Payment.where(group_id: group.id).pluck(:id)
        expense_ids = Expense.where(group_id: group.id).pluck(:id)
        delete_payment_command_receipts_for_cleanup!(PaymentCommandReceipt.where(payment_id: payment_ids))
        Payment.where(id: payment_ids).delete_all
        ExpenseShare.where(expense_id: expense_ids).delete_all
        Expense.where(id: expense_ids).delete_all
        Membership.where(group_id: group.id).delete_all
        Group.where(id: group.id).delete_all
      end
      User.where(id: [ receiver&.id, sender&.id ].compact).delete_all
    rescue StandardError => cleanup_error
      warn "payment reporter global collision cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  def report(group:, sender:, receiver:, expected_version:)
    described_class.call(
      group_id: group.id,
      actor_user_id: sender.id,
      from_user_id: sender.id,
      to_user_id: receiver.id,
      amount_text: "3,00",
      expected_financial_state_version: expected_version,
      idempotency_key: SecureRandom.uuid
    )
  end

  def wait_for_lock(backend_pid)
    Timeout.timeout(5) do
      loop do
        wait_event_type = ApplicationRecord.connection.select_value(
          ApplicationRecord.sanitize_sql_array([ "SELECT wait_event_type FROM pg_stat_activity WHERE pid = ?", backend_pid ])
        )
        return wait_event_type if wait_event_type == "Lock"

        sleep 0.02
      end
    end
  end
end
