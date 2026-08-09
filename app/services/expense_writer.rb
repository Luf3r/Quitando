class ExpenseWriter
  UUID_V7_PATTERN = ExpenseCreator::UUID_V7_PATTERN

  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group:, created_by_user_id:, paid_by_user_id:, description:, occurred_on:, amount_text:, split:, invalid_expense_class:, replaces_expense: nil)
    @group = group
    @created_by_user_id = created_by_user_id
    @paid_by_user_id = paid_by_user_id
    @description = description
    @occurred_on = occurred_on
    @amount_text = amount_text
    @split = split
    @invalid_expense_class = invalid_expense_class
    @replaces_expense = replaces_expense
  end

  def call
    amount_cents = MoneyParser.parse_cents(amount_text)
    shares = split_shares(amount_cents)
    validate_non_payer_obligation!(shares)

    expense = Expense.create!(
      group:,
      created_by_user_id:,
      paid_by_user_id:,
      amount_cents:,
      description:,
      occurred_on:,
      replaces_expense:
    )
    shares.sort_by { |share| share.fetch(:position) }.each_with_index do |share, position|
      ExpenseShare.create!(expense:, user_id: share.fetch(:user_id), amount_owed_cents: share.fetch(:amount_owed_cents), position:)
    end
    expense
  end

  private

  attr_reader :group, :created_by_user_id, :paid_by_user_id, :description, :occurred_on, :amount_text, :split, :invalid_expense_class, :replaces_expense

  def split_shares(amount_cents)
    raise_invalid_split unless split.is_a?(Hash)
    return equal_shares(amount_cents) if split[:type] == :equal
    return exact_shares(amount_cents) if split[:type] == :exact

    raise_invalid_split
  end

  def equal_shares(amount_cents)
    participant_ids = split[:participant_user_ids]
    raise_invalid_split unless valid_user_ids?(participant_ids) && participant_ids.uniq.length == participant_ids.length

    active_memberships = Membership.where(group:, user_id: participant_ids).active.order(:position).to_a
    required_ids = participant_ids | [ created_by_user_id, paid_by_user_id ]
    active_ids = Membership.where(group:, user_id: required_ids, status: :active).pluck(:user_id)
    raise invalid_expense_class, "membership ativa obrigatória" unless active_ids.sort == required_ids.sort && active_memberships.map(&:user_id).sort == participant_ids.sort

    EqualSplitCalculator.call(amount_cents:, memberships: active_memberships, paid_by_user_id:)
  rescue EqualSplitCalculator::InvalidSplit
    raise_invalid_split
  end

  def exact_shares(amount_cents)
    entries = split[:shares]
    raise_invalid_split unless entries.is_a?(Array) && entries.any? && entries.all? { |entry| valid_exact_entry?(entry) }

    user_ids = entries.map { |entry| entry[:user_id] }
    raise invalid_expense_class, "shares duplicadas" unless user_ids.uniq.length == user_ids.length

    memberships = active_memberships_for!(user_ids | [ created_by_user_id, paid_by_user_id ])
    amounts = entries.map { |entry| MoneyParser.parse_cents(entry[:amount_text]) }
    raise invalid_expense_class, "soma das shares diverge da despesa" unless amounts.sum == amount_cents

    entries.each_with_index.map do |entry, index|
      { user_id: entry.fetch(:user_id), amount_owed_cents: amounts.fetch(index), position: memberships.fetch(entry.fetch(:user_id)).position }
    end
  rescue MoneyParser::InvalidAmount
    raise_invalid_split
  end

  def active_memberships_for!(user_ids)
    found = Membership.where(group:, user_id: user_ids, status: :active).index_by(&:user_id)
    raise invalid_expense_class, "membership ativa obrigatória" unless found.keys.sort == user_ids.sort

    found
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
    raise invalid_expense_class, "despesa deve gerar obrigação para não pagador" unless shares.any? { |share| share.fetch(:user_id) != paid_by_user_id }
  end

  def raise_invalid_split
    raise invalid_expense_class, "divisão inválida"
  end
end
