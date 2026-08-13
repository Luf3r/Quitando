require "rails_helper"
require "timeout"

RSpec.describe "Group invitation terminal transition race", :non_transactional do
  self.use_transactional_tests = false

  it "commits one terminal transition when acceptance races revocation" do
    group = create(:group)
    owner = create(:user)
    invited_user = create(:user)
    create(:membership, group:, user: owner, role: :owner, position: 0)
    invitation = create(:group_invitation, group:, invited_user:, invited_by_user: owner, expires_at: 2.days.from_now)
    lock_acquired = Queue.new
    release_lock = Queue.new
    second_session_started = Queue.new
    backend_pids = Queue.new
    results = Queue.new

    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backend_pids << connection.select_value("SELECT pg_backend_pid()").to_i
        connection.transaction do
          Group.lock.find(group.id)
          lock_acquired << true
          release_lock.pop
          results << GroupInvitationAccepter.call(invitation_id: invitation.id, actor_user_id: invited_user.id)
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
        second_session_started << true
        results << GroupInvitationRevoker.call(invitation_id: invitation.id, actor_user_id: owner.id)
      ensure
        connection.execute("RESET lock_timeout")
      end
    rescue StandardError => error
      results << error
    end

    Timeout.timeout(5) { second_session_started.pop }
    second_backend_pid = Timeout.timeout(5) { backend_pids.pop }
    expect(second_backend_pid).not_to eq(first_backend_pid)
    expect(wait_for_lock(second_backend_pid)).to eq("Lock")

    release_lock << true
    expect(first_thread.join(10)).to eq(first_thread)
    expect(second_thread.join(10)).to eq(second_thread)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values.count { |value| value.is_a?(GroupInvitationAccepter::Result) }).to eq(1)
    expect(values.grep(GroupCommand::InvalidTransition)).to contain_exactly(
      have_attributes(message: "convite não está pendente")
    )
    expect(invitation.reload).to be_accepted
    expect(Membership.where(group:, user: invited_user).count).to eq(1)
  ensure
    release_lock << true if release_lock
    [ first_thread, second_thread ].compact.each { |thread| thread.kill if thread.alive? }
    Timeout.timeout(5) { [ first_thread, second_thread ].compact.each(&:join) }
    GroupInvitation.where(group_id: group&.id).delete_all if group
    Membership.where(group_id: group&.id).delete_all if group
    Group.where(id: group&.id).delete_all if group
    User.where(id: [ owner&.id, invited_user&.id ].compact).delete_all
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
