require "rails_helper"
require "timeout"

RSpec.describe ExpenseCorrector, :non_transactional do
  self.use_transactional_tests = false

  it "serializa correções distintas da mesma versão em sessões PostgreSQL independentes" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    user_ids = [ owner.id, participant.id ]
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
    expected_version = group.reload.financial_state_version
    lock_acquired = Queue.new
    release_lock = Queue.new
    second_started = Queue.new
    backend_pids = Queue.new
    results = Queue.new

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        connection.transaction do
          connection.execute("SET LOCAL lock_timeout = '5s'")
          Group.lock.find(group.id)
          lock_acquired << true
          release_lock.pop
          results << correct(group:, original:, owner:, participant:, expected_version:, amount_text: "12,00")
        end
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(5) { lock_acquired.pop }
    first_backend_pid = Timeout.timeout(5) { backend_pids.pop }
    second_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '5s'")
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        second_started << true
        results << correct(group:, original:, owner:, participant:, expected_version:, amount_text: "14,00")
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(5) { second_started.pop }
    second_backend_pid = Timeout.timeout(5) { backend_pids.pop }
    expect(second_backend_pid).not_to eq(first_backend_pid)
    expect(wait_for_lock(second_backend_pid)).to eq("Lock")

    release_lock << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values.count { |value| value.is_a?(Expense) }).to eq(1)
    expect(values.grep(ExpenseCorrector::StaleFinancialState).length).to eq(1)
    expect(original.reload.voided_at).to be_present
    expect(Expense.where(replaces_expense_id: original.id).count).to eq(1)
    expect(group.reload.financial_state_version).to eq(2)
  ensure
    primary_error = $!
    begin
      release_lock << true if release_lock
      [ first_thread, second_thread ].compact.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { [ first_thread, second_thread ].compact.each(&:join) }
      if group&.persisted?
        expense_ids = Expense.where(group_id: group.id).pluck(:id)
        delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: expense_ids))
        delete_expense_history_for_cleanup!(Expense.where(id: expense_ids))
        Membership.where(group_id: group.id).delete_all
        Group.where(id: group.id).delete_all
      end
      User.where(id: user_ids).delete_all if user_ids
    rescue StandardError => cleanup_error
      warn "expense corrector concurrency cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  it "traduz colisão simultânea de chave global entre grupos para conflito de domínio" do
    owner = create(:user)
    participant = create(:user)
    user_ids = [ owner.id, participant.id ]
    groups = 2.times.map do
      group = create(:group)
      [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
      original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
      [ group, original, group.reload.financial_state_version ]
    end
    key = SecureRandom.uuid
    holder_ready = Queue.new
    release_holder = Queue.new
    contender_started = Queue.new
    backend_pids = Queue.new
    results = Queue.new
    first_group, first_original, first_version = groups.first
    second_group, second_original, second_version = groups.second

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        result = nil
        connection.transaction do
          result = correct(group: first_group, original: first_original, owner:, participant:, expected_version: first_version, amount_text: "12,00", idempotency_key: key)
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
        results << correct(group: second_group, original: second_original, owner:, participant:, expected_version: second_version, amount_text: "12,00", idempotency_key: key)
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

    expect(values.count { |value| value.is_a?(Expense) }).to eq(1)
    expect(values.grep(ExpenseCorrector::IdempotencyConflict).length).to eq(1)
  ensure
    primary_error = $!
    begin
      release_holder << true if release_holder
      [ first_thread, second_thread ].compact.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { [ first_thread, second_thread ].compact.each(&:join) }
      groups&.each do |group, _original, _version|
        expense_ids = Expense.where(group_id: group.id).pluck(:id)
        delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: expense_ids))
        delete_expense_history_for_cleanup!(Expense.where(id: expense_ids))
        Membership.where(group_id: group.id).delete_all
        Group.where(id: group.id).delete_all
      end
      User.where(id: user_ids).delete_all if user_ids
    rescue StandardError => cleanup_error
      warn "expense corrector global collision cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  it "retorna a mesma substituta para correções concorrentes com a mesma chave e payload" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    user_ids = [ owner.id, participant.id ]
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
    expected_version = group.reload.financial_state_version
    key = SecureRandom.uuid
    lock_acquired = Queue.new
    release_lock = Queue.new
    results = Queue.new

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.transaction do
          Group.lock.find(group.id)
          lock_acquired << true
          release_lock.pop
          results << correct(group:, original:, owner:, participant:, expected_version:, amount_text: "12,00", idempotency_key: key)
        end
      end
    rescue StandardError => error
      results << error
    end
    Timeout.timeout(5) { lock_acquired.pop }

    second_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        results << correct(group:, original:, owner:, participant:, expected_version:, amount_text: "12,00", idempotency_key: key)
      end
    rescue StandardError => error
      results << error
    end

    release_lock << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    first, second = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect([ first, second ]).to all(be_a(Expense))
    expect(first.id).to eq(second.id)
    expect(Expense.where(replaces_expense_id: original.id).count).to eq(1)
    expect(FinancialCommandReceipt.where(expense_id: first.id, command_type: :expense_correct).count).to eq(1)
    expect(group.reload.financial_state_version).to eq(2)
  ensure
    primary_error = $!
    begin
      release_lock << true if release_lock
      [ first_thread, second_thread ].compact.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { [ first_thread, second_thread ].compact.each(&:join) }
      if group&.persisted?
        expense_ids = Expense.where(group_id: group.id).pluck(:id)
        delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: expense_ids))
        delete_expense_history_for_cleanup!(Expense.where(id: expense_ids))
        Membership.where(group_id: group.id).delete_all
        Group.where(id: group.id).delete_all
      end
      User.where(id: user_ids).delete_all if user_ids
    rescue StandardError => cleanup_error
      warn "expense corrector retry cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  it "rejeita um report concorrente que observou a versão anterior à correção" do
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    user_ids = [ owner.id, participant.id ]
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    original = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Jantar", occurred_on: Date.new(2026, 8, 3), amount_text: "10,00", split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "5,00" }, { user_id: participant.id, amount_text: "5,00" } ] })
    expected_version = group.reload.financial_state_version
    lock_acquired = Queue.new
    release_lock = Queue.new
    backend_pids = Queue.new
    results = Queue.new

    correction_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.transaction do
          Group.lock.find(group.id)
          lock_acquired << true
          release_lock.pop
          results << correct(group:, original:, owner:, participant:, expected_version:, amount_text: "12,00")
        end
      end
    rescue StandardError => error
      results << error
    end
    Timeout.timeout(5) { lock_acquired.pop }

    report_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '5s'")
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        results << PaymentReporter.call(group_id: group.id, actor_user_id: participant.id, from_user_id: participant.id, to_user_id: owner.id, amount_text: "5,00", expected_financial_state_version: expected_version, idempotency_key: SecureRandom.uuid)
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    report_backend_pid = Timeout.timeout(5) { backend_pids.pop }
    expect(wait_for_lock(report_backend_pid)).to eq("Lock")
    release_lock << true
    expect(correction_thread.join(10)).to eq(correction_thread)
    expect(report_thread.join(10)).to eq(report_thread)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values.count { |value| value.is_a?(Expense) }).to eq(1)
    expect(values.grep(PaymentCommand::StaleFinancialState)).to have_attributes(length: 1)
    expect(Payment.where(group:)).to be_empty
    expect(group.reload.financial_state_version).to eq(2)
  ensure
    primary_error = $!
    begin
      release_lock << true if release_lock
      [ correction_thread, report_thread ].compact.each { |thread| thread.kill if thread.alive? }
      Timeout.timeout(5) { [ correction_thread, report_thread ].compact.each(&:join) }
      if group&.persisted?
        expense_ids = Expense.where(group_id: group.id).pluck(:id)
        delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: expense_ids))
        delete_expense_history_for_cleanup!(Expense.where(id: expense_ids))
        Membership.where(group_id: group.id).delete_all
        Group.where(id: group.id).delete_all
      end
      User.where(id: user_ids).delete_all if user_ids
    rescue StandardError => cleanup_error
      warn "expense corrector/report cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  def correct(group:, original:, owner:, participant:, expected_version:, amount_text:, idempotency_key: SecureRandom.uuid)
    described_class.call(group_id: group.id, expense_id: original.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Jantar corrigido", occurred_on: original.occurred_on, amount_text:, split: { type: :exact, shares: [ { user_id: owner.id, amount_text: "6,00" }, { user_id: participant.id, amount_text: (MoneyParser.parse_cents(amount_text) - 600).then { |cents| format("%d,%02d", cents / 100, cents % 100) } } ] }, expected_financial_state_version: expected_version, idempotency_key:)
  end

  def wait_for_lock(backend_pid)
    Timeout.timeout(5) do
      loop do
        wait_event_type = ApplicationRecord.connection.select_value(ApplicationRecord.sanitize_sql_array([ "SELECT wait_event_type FROM pg_stat_activity WHERE pid = ?", backend_pid ]))
        return wait_event_type if wait_event_type == "Lock"

        sleep 0.02
      end
    end
  end
end
