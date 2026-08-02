require "rails_helper"
require "timeout"

RSpec.describe "Payment terminal transition race", :non_transactional do
  self.use_transactional_tests = false

  it "commits exactly one terminal transition when confirmation races cancellation" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    created_user_ids = [ receiver.id, sender.id ]
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    values = run_contended_race(
      holder: -> { PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid) },
      contender: -> { PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: SecureRandom.uuid) }
    )

    expect(values.count { |value| value.is_a?(Payment) }).to eq(1)
    expect(values.grep(PaymentCommand::InvalidTransition).length).to eq(1)
    expect(payment.reload).to be_confirmed
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:).count).to eq(1)
  ensure
    primary_error = $!
    begin
      ApplicationRecord.transaction do
        ApplicationRecord.connection.execute("SET LOCAL lock_timeout = '5s'")
        if group&.persisted?
          delete_payment_command_receipts_for_cleanup!(PaymentCommandReceipt.where(payment_id: payment.id)) if payment
          Payment.where(id: payment.id).delete_all if payment
          Membership.where(group_id: group.id).delete_all
          Group.where(id: group.id).delete_all
        end
        User.where(id: created_user_ids).delete_all if created_user_ids
      end
    rescue StandardError => cleanup_error
      warn "payment terminal race cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
      raise cleanup_error unless primary_error
    end
  end

  it "commits one confirmation when two receivers confirm concurrently" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    created_user_ids = [ receiver.id, sender.id ]
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    confirm = -> { PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: SecureRandom.uuid) }
    values = run_contended_race(holder: confirm, contender: confirm)

    expect(values.count { |value| value.is_a?(Payment) }).to eq(1)
    expect(values.grep(PaymentCommand::InvalidTransition).length).to eq(1)
    expect(payment.reload).to be_confirmed
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:).count).to eq(1)
  ensure
    cleanup_race(group:, payment:, created_user_ids:, primary_error: $!)
  end

  it "commits one cancellation when two participants cancel concurrently" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    created_user_ids = [ receiver.id, sender.id ]
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    cancel = -> { PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: SecureRandom.uuid) }
    values = run_contended_race(holder: cancel, contender: cancel)

    expect(values.count { |value| value.is_a?(Payment) }).to eq(1)
    expect(values.grep(PaymentCommand::InvalidTransition).length).to eq(1)
    expect(payment.reload).to be_cancelled
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:).count).to eq(1)
  ensure
    cleanup_race(group:, payment:, created_user_ids:, primary_error: $!)
  end

  it "converges two concurrent confirmations with the same key to one receipt, version and event" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    created_user_ids = [ receiver.id, sender.id ]
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    key = SecureRandom.uuid
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.confirmed") { |event| events << event.payload }
    confirm = -> { PaymentConfirmer.call(group_id: group.id, payment_id: payment.id, actor_user_id: receiver.id, idempotency_key: key) }

    values = run_contended_race(holder: confirm, contender: confirm)

    expect(values).to all(be_a(Payment))
    expect(values.map(&:id).uniq).to eq([ payment.id ])
    expect(payment.reload).to be_confirmed
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:).count).to eq(1)
    expect(events).to contain_exactly(include(payment_id: payment.id, group_id: group.id, actor_user_id: receiver.id, financial_state_version: 1))
  ensure
    primary_error = $!
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_race(group:, payment:, created_user_ids:, primary_error:)
  end

  it "converges two concurrent cancellations with the same key to one receipt, version and event" do
    group = create(:group)
    receiver = create(:user)
    sender = create(:user)
    created_user_ids = [ receiver.id, sender.id ]
    [ receiver, sender ].each_with_index { |user, position| create(:membership, group:, user:, position:) }
    payment = create(:payment, group:, from_user: sender, to_user: receiver, reported_by_user: sender)
    key = SecureRandom.uuid
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("quitando.payment.cancelled") { |event| events << event.payload }
    cancel = -> { PaymentCanceller.call(group_id: group.id, payment_id: payment.id, actor_user_id: sender.id, reason: "não enviado", idempotency_key: key) }

    values = run_contended_race(holder: cancel, contender: cancel)

    expect(values).to all(be_a(Payment))
    expect(values.map(&:id).uniq).to eq([ payment.id ])
    expect(payment.reload).to be_cancelled
    expect(group.reload.financial_state_version).to eq(1)
    expect(PaymentCommandReceipt.where(payment:).count).to eq(1)
    expect(events).to contain_exactly(include(payment_id: payment.id, group_id: group.id, actor_user_id: sender.id, financial_state_version: 1))
  ensure
    primary_error = $!
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    cleanup_race(group:, payment:, created_user_ids:, primary_error:)
  end

  def cleanup_race(group:, payment:, created_user_ids:, primary_error:)
    ApplicationRecord.transaction do
      ApplicationRecord.connection.execute("SET LOCAL lock_timeout = '5s'")
      if group&.persisted?
        delete_payment_command_receipts_for_cleanup!(PaymentCommandReceipt.where(payment_id: payment.id)) if payment
        Payment.where(id: payment.id).delete_all if payment
        Membership.where(group_id: group.id).delete_all
        Group.where(id: group.id).delete_all
      end
      User.where(id: created_user_ids).delete_all if created_user_ids
    end
  rescue StandardError => cleanup_error
    warn "payment terminal race cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}"
    raise cleanup_error unless primary_error
  end

  def run_contended_race(holder:, contender:)
    holder_ready = Queue.new
    release_holder = Queue.new
    contender_started = Queue.new
    backend_pids = Queue.new
    results = Queue.new

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        result = nil
        connection.transaction do
          connection.execute("SET LOCAL lock_timeout = '5s'")
          result = holder.call
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
        results << contender.call
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
    2.times.map { Timeout.timeout(5) { results.pop } }
  ensure
    release_holder << true if release_holder
    threads = [ first_thread, second_thread ].compact
    threads.each { |thread| thread.kill if thread.alive? }
    Timeout.timeout(5) { threads.each(&:join) }
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
