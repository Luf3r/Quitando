require "rails_helper"
require "timeout"

RSpec.describe GroupDashboardQuery, :non_transactional do
  self.use_transactional_tests = false

  it "mantém o lock do grupo durante a composição e não permite commit financeiro intercalado" do
    group = create(:group)
    owner = create(:user)
    member = create(:user)
    created_user_ids = [ owner.id, member.id ]
    create(:membership, group:, user: owner, role: :owner, position: 0)
    create(:membership, group:, user: member, position: 1)
    writer_ready = Queue.new
    create_expense = Queue.new
    expense_created = Queue.new
    writer_backend_pid = nil

    writer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        writer_ready << ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
        create_expense.pop
        ExpenseCreator.call(
          group_id: group.id,
          created_by_user_id: owner.id,
          paid_by_user_id: owner.id,
          description: "Despesa concorrente",
          occurred_on: Date.new(2026, 8, 23),
          amount_text: "1,00",
          split: { type: :exact, shares: [ { user_id: member.id, amount_text: "1,00" } ] }
        )
        expense_created << true
      end
    rescue StandardError => error
      expense_created << error
    end

    writer_backend_pid = Timeout.timeout(5) { writer_ready.pop }
    allow(ObligationGraphBuilder).to receive(:call).and_wrap_original do |original, received_group|
      create_expense << true
      wait_for_writer_lock!(writer_backend_pid)

      original.call(received_group)
    end

    snapshot = described_class.call(group:, viewer: owner)

    expect(writer.join(5)).to eq(writer)
    expect(snapshot.settlement_plan).to be_empty
    expect(snapshot.visualization.historical).to be_empty
    expect(snapshot.visualization.plan).to be_empty
    outcome = Timeout.timeout(5) { expense_created.pop }
    raise outcome if outcome.is_a?(StandardError)
    expect(group.reload.financial_state_version).to eq(1)
  ensure
    create_expense << true if create_expense
    writer.kill if writer&.alive?
    Timeout.timeout(5) { writer.join } if writer

    expense_ids = Expense.where(group_id: group&.id).pluck(:id)
    delete_expense_history_for_cleanup!(Expense.where(id: expense_ids)) if expense_ids.any?
    Membership.where(group_id: group&.id).delete_all if group
    Group.where(id: group&.id).delete_all if group
    User.where(id: created_user_ids).delete_all if created_user_ids
  end

  def wait_for_writer_lock!(backend_pid)
    Timeout.timeout(5) do
      loop do
        wait_event_type = ActiveRecord::Base.connection.select_value(
          "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}"
        )
        return if wait_event_type == "Lock"

        sleep 0.01
      end
    end
  end
end
