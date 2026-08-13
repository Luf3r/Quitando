require "rails_helper"
require "timeout"

RSpec.describe ExpenseDescriptionEditor, :non_transactional do
  self.use_transactional_tests = false

  it "serializa duas edições e preserva uma cadeia de revisões sem versão financeira" do
    group, owner, participant, expense = editable_expense
    user_ids = [ owner.id, participant.id ]
    start = Queue.new
    results = Queue.new

    threads = [ "Mercado A", "Mercado B" ].map do |description|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          results << described_class.call(group_id: group.id, expense_id: expense.id, actor_user_id: owner.id, description:)
        end
      rescue StandardError => error
        results << error
      end
    end
    2.times { start << true }
    expect(threads).to all(satisfy { |thread| thread.join(10) == thread })
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values).to all(be_a(Expense))
    revisions = ExpenseDescriptionRevision.where(expense:).order(:created_at, :id).pluck(:previous_description, :new_description)
    expect(revisions.length).to eq(2)
    expect(revisions.first.last).to eq(revisions.last.first)
    expect(revisions.first.first).to eq("Mercado")
    expect(revisions.last.last).to eq(expense.reload.description)
    expect(group.reload.financial_state_version).to eq(1)
  ensure
    cleanup_editor_concurrency(group, user_ids)
  end

  it "deixa uma revisão consistente antes de uma correção concorrente e não entra em deadlock" do
    group, owner, participant, expense = editable_expense
    user_ids = [ owner.id, participant.id ]
    lock_acquired = Queue.new
    release_lock = Queue.new
    results = Queue.new

    editor_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.transaction do
          Expense.lock.find(expense.id)
          lock_acquired << true
          release_lock.pop
          results << described_class.call(group_id: group.id, expense_id: expense.id, actor_user_id: owner.id, description: "Mercado editado")
        end
      end
    rescue StandardError => error
      results << error
    end
    Timeout.timeout(5) { lock_acquired.pop }

    corrector_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        results << ExpenseCorrector.call(group_id: group.id, expense_id: expense.id, actor_user_id: owner.id, reason: "Valor corrigido", paid_by_user_id: owner.id, description: "Mercado corrigido", occurred_on: expense.occurred_on, amount_text: "4,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] }, expected_financial_state_version: 1, idempotency_key: SecureRandom.uuid)
      end
    rescue StandardError => error
      results << error
    end

    release_lock << true
    expect(editor_thread.join(10)).to eq(editor_thread)
    expect(corrector_thread.join(10)).to eq(corrector_thread)
    values = 2.times.map { Timeout.timeout(5) { results.pop } }

    expect(values.count { |value| value.is_a?(Expense) }).to eq(2)
    expect(ExpenseDescriptionRevision.where(expense:)).to contain_exactly(have_attributes(previous_description: "Mercado", new_description: "Mercado editado"))
    expect(expense.reload).to have_attributes(description: "Mercado editado", voided_at: be_present)
    expect(group.reload.financial_state_version).to eq(2)
  ensure
    release_lock << true if release_lock
    cleanup_editor_concurrency(group, user_ids)
  end

  def editable_expense
    group = create(:group)
    owner = create(:user)
    participant = create(:user)
    [ owner, participant ].each_with_index { |user, position| create(:membership, group:, user:, role: user == owner ? :owner : :member, position:) }
    expense = ExpenseCreator.call(group_id: group.id, created_by_user_id: owner.id, paid_by_user_id: owner.id, description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00", split: { type: :equal, participant_user_ids: [ owner.id, participant.id ] })
    [ group, owner, participant, expense ]
  end

  def cleanup_editor_concurrency(group, user_ids)
    return unless group&.persisted?

    expense_ids = Expense.where(group_id: group.id).pluck(:id)
    delete_payment_command_receipts_for_cleanup!(FinancialCommandReceipt.where(expense_id: expense_ids))
    delete_expense_description_revisions_for_cleanup!(ExpenseDescriptionRevision.where(expense_id: expense_ids))
    delete_expense_history_for_cleanup!(Expense.where(id: expense_ids))
    Membership.where(group_id: group.id).delete_all
    Group.where(id: group.id).delete_all
    User.where(id: user_ids).delete_all if user_ids
  end
end
