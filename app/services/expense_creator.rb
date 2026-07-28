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

      amount_cents = MoneyParser.parse_cents(amount_text)
      shares = split_shares(amount_cents)
      validate_non_payer_obligation!(shares)

      expense = Expense.create!(
        group:,
        created_by_user_id:,
        paid_by_user_id:,
        amount_cents:,
        description:,
        occurred_on:
      )
      shares.sort_by { |share| share.fetch(:position) }.each_with_index do |share, position|
        ExpenseShare.create!(expense:, user_id: share.fetch(:user_id), amount_owed_cents: share.fetch(:amount_owed_cents), position:)
      end
      group.increment!(:financial_state_version)
      schedule_created_by_third_party_event(expense) if created_by_user_id != paid_by_user_id
      expense
    end
  end

  private

  attr_reader :group_id, :created_by_user_id, :paid_by_user_id, :description, :occurred_on, :amount_text, :split

  def split_shares(amount_cents)
    raise InvalidExpense, "divisão inválida" unless split.is_a?(Hash)
    return equal_shares(amount_cents) if split[:type] == :equal
    return exact_shares(amount_cents) if split[:type] == :exact

    raise InvalidExpense, "divisão inválida"
  end

  def equal_shares(amount_cents)
    participant_ids = split[:participant_user_ids]
    unless valid_user_ids?(participant_ids) && participant_ids.uniq.length == participant_ids.length
      raise InvalidExpense, "divisão inválida"
    end

    active_memberships = Membership.where(group_id:, user_id: participant_ids).active.order(:position).to_a
    required_ids = participant_ids | [ created_by_user_id, paid_by_user_id ]
    active_ids = Membership.where(group_id:, user_id: required_ids, status: :active).pluck(:user_id)
    raise InvalidExpense, "membership ativa obrigatória" unless active_ids.sort == required_ids.sort && active_memberships.map(&:user_id).sort == participant_ids.sort

    EqualSplitCalculator.call(amount_cents:, memberships: active_memberships, paid_by_user_id:)
  rescue EqualSplitCalculator::InvalidSplit
    raise InvalidExpense, "divisão inválida", cause: nil
  end

  def exact_shares(amount_cents)
    entries = split[:shares]
    unless entries.is_a?(Array) && entries.any? && entries.all? { |entry| valid_exact_entry?(entry) }
      raise InvalidExpense, "divisão inválida"
    end

    user_ids = entries.map { |entry| entry[:user_id] }
    raise InvalidExpense, "shares duplicadas" unless user_ids.uniq.length == user_ids.length
    memberships = active_memberships_for!(user_ids | [ created_by_user_id, paid_by_user_id ])
    amounts = entries.map { |entry| MoneyParser.parse_cents(entry[:amount_text]) }
    raise InvalidExpense, "soma das shares diverge da despesa" unless amounts.sum == amount_cents

    entries.each_with_index.map do |entry, index|
      { user_id: entry.fetch(:user_id), amount_owed_cents: amounts.fetch(index), position: memberships.fetch(entry.fetch(:user_id)).position }
    end
  rescue MoneyParser::InvalidAmount
    raise InvalidExpense, "divisão inválida", cause: nil
  end

  def active_memberships_for!(user_ids)
    found = Membership.where(group_id:, user_id: user_ids, status: :active).index_by(&:user_id)
    raise InvalidExpense, "membership ativa obrigatória" unless found.keys.sort == user_ids.sort

    found
  end

  def validate_command_identifiers!
    identifiers = [ group_id, created_by_user_id, paid_by_user_id ]
    raise InvalidExpense, "identificadores inválidos" unless identifiers.all? { |identifier| valid_uuid?(identifier) }
  end

  def valid_user_ids?(user_ids)
    user_ids.is_a?(Array) && user_ids.any? && user_ids.all? { |user_id| valid_uuid?(user_id) }
  end

  def valid_exact_entry?(entry)
    entry.is_a?(Hash) && valid_uuid?(entry[:user_id]) && entry[:amount_text].is_a?(String)
  end

  def valid_uuid?(value)
    value.is_a?(String) && UUID_V7_PATTERN.match?(value)
  end

  def validate_non_payer_obligation!(shares)
    raise InvalidExpense, "despesa deve gerar obrigação para não pagador" unless shares.any? { |share| share.fetch(:user_id) != paid_by_user_id }
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
