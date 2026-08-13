require "rails_helper"
require "timeout"

RSpec.describe MembershipDeactivator, :non_transactional do
  self.use_transactional_tests = false

  it "faz criação de despesa falhar quando a inativação vence o lock do grupo" do
    group = create(:group)
    owner = create(:user)
    member = create(:user)
    create(:membership, group:, user: owner, role: :owner, position: 0)
    create(:membership, group:, user: member, position: 1)
    locked = Queue.new
    release = Queue.new
    results = Queue.new

    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.transaction do
          Group.lock.find(group.id)
          locked << true
          release.pop
          results << described_class.call(group_id: group.id, actor_user_id: member.id, user_id: member.id)
        end
      end
    rescue StandardError => error
      locked << error
      results << error
    end
    lock_state = Timeout.timeout(5) { locked.pop }
    raise lock_state if lock_state.is_a?(StandardError)

    second = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |_connection|
        results << ExpenseCreator.call(
          group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id,
          description: "Depois da saída", occurred_on: Date.current, amount_text: "2,00",
          split: { type: :equal, participant_user_ids: [ owner.id, member.id ] }
        )
      end
    rescue StandardError => error
      results << error
    end

    release << true
    expect(first.join(10)).to eq(first)
    expect(second.join(10)).to eq(second)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values.count { |value| value.is_a?(Membership) }).to eq(1)
    expect(values.grep(ExpenseCreator::InvalidExpense)).to contain_exactly(have_attributes(message: "membership ativa obrigatória"))
    expect(Expense.where(group:)).to be_empty
  ensure
    release << true if release
    [ first, second ].compact.each { |thread| thread.kill if thread.alive? }
    Timeout.timeout(5) { [ first, second ].compact.each(&:join) }
    Membership.where(group_id: group&.id).delete_all if group
    Group.where(id: group&.id).delete_all if group
    User.where(id: [ owner&.id, member&.id ].compact).delete_all
  end
end
