class ExpenseCreator
  class InvalidExpense < ArgumentError; end

  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, created_by_user_id:, paid_by_user_id:, description:, occurred_on:, amount_text:, split:)
    @group_id = group_id
    @created_by_user_id = created_by_user_id
    @paid_by_user_id = paid_by_user_id
    @description = description
    @occurred_on = occurred_on
    @amount_text = amount_text
    @split = split
  end

  def call
    validate_command_identifiers!

    Group.transaction do
      group = Group.lock.find(group_id)
      raise InvalidExpense, "grupo arquivado" if group.archived_at?

      expense = ExpenseWriter.call(
        group:,
        created_by_user_id:,
        paid_by_user_id:,
        description:,
        occurred_on:,
        amount_text:,
        split:,
        invalid_expense_class: InvalidExpense
      )
      group.increment!(:financial_state_version)
      schedule_created_by_third_party_event(expense) if created_by_user_id != paid_by_user_id
      expense
    end
  end

  private

  attr_reader :group_id, :created_by_user_id, :paid_by_user_id, :description, :occurred_on, :amount_text, :split

  def validate_command_identifiers!
    identifiers = [ group_id, created_by_user_id, paid_by_user_id ]
    raise InvalidExpense, "identificadores inválidos" unless identifiers.all? { |identifier| valid_uuid?(identifier) }
    raise InvalidExpense, "identificadores inválidos" unless split_user_ids.all? { |identifier| valid_uuid?(identifier) }
  end

  def split_user_ids
    raise InvalidExpense, "divisão inválida" unless split.is_a?(Hash)
    if split[:type] == :equal
      participant_user_ids = split[:participant_user_ids]
      raise InvalidExpense, "divisão inválida" unless participant_user_ids.is_a?(Array) && participant_user_ids.any?

      return participant_user_ids
    end
    if split[:type] == :exact
      shares = split[:shares]
      valid_entries = shares.is_a?(Array) && shares.any? && shares.all? { |share| share.is_a?(Hash) && share.key?(:user_id) && share[:amount_text].is_a?(String) }
      raise InvalidExpense, "divisão inválida" unless valid_entries

      return shares.map { |share| share[:user_id] }
    end

    raise InvalidExpense, "divisão inválida"
  end

  def valid_uuid?(value)
    value.is_a?(String) && UUID_V7_PATTERN.match?(value)
  end

  def schedule_created_by_third_party_event(expense)
    payload = {
      expense_id: expense.id,
      group_id: expense.group_id,
      recipient_user_id: paid_by_user_id,
      created_by_user_id:
    }.freeze
    ActiveRecord.after_all_transactions_commit do
      publish_created_by_third_party_event(payload)
    end
  end

  def publish_created_by_third_party_event(payload)
    ActiveSupport::Notifications.instrument("quitando.expense.created_by_third_party", payload)
  rescue StandardError => error
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: payload,
      source: "quitando.expense.created_by_third_party"
    )
  end
end
