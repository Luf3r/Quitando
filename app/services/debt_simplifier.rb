class DebtSimplifier
  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  Transfer = Data.define(:from_user_id, :to_user_id, :amount_cents)
  BalanceEntry = Data.define(:user_id, :amount_cents)

  class BinaryMaxHeap
    def initialize(&higher_priority)
      @elements = []
      @higher_priority = higher_priority
    end

    def push(element)
      elements << element
      sift_up(elements.length - 1)
      self
    end

    def pop
      return if elements.empty?
      return elements.pop if elements.length == 1

      highest_priority = elements.first
      elements[0] = elements.pop
      sift_down(0)
      highest_priority
    end

    def empty?
      elements.empty?
    end

    private

    attr_reader :elements, :higher_priority

    def sift_up(index)
      while index.positive?
        parent_index = (index - 1) / 2
        break unless higher_priority.call(elements[index], elements[parent_index])

        elements[index], elements[parent_index] = elements[parent_index], elements[index]
        index = parent_index
      end
    end

    def sift_down(index)
      loop do
        left_index = (index * 2) + 1
        break if left_index >= elements.length

        right_index = left_index + 1
        child_index = if right_index < elements.length &&
            higher_priority.call(elements[right_index], elements[left_index])
          right_index
        else
          left_index
        end

        break unless higher_priority.call(elements[child_index], elements[index])

        elements[index], elements[child_index] = elements[child_index], elements[index]
        index = child_index
      end
    end
  end

  private_constant :BalanceEntry, :BinaryMaxHeap

  class InvalidBalances < ArgumentError; end
  class InvalidUserId < ArgumentError; end
  class InvalidBalance < ArgumentError; end
  class UnbalancedBalances < ArgumentError; end

  def initialize(balances)
    raise InvalidBalances unless balances.is_a?(Hash)

    @balances = balances.dup
  end

  def call
    validate_structure!
    validate_user_ids!
    validate_balance_values!
    validate_zero_sum!

    settle_balances
  end

  private

  attr_reader :balances

  def validate_structure!
    raise InvalidBalances unless balances.is_a?(Hash)
  end

  def validate_user_ids!
    valid_user_ids = balances.each_key.all? do |user_id|
      user_id.is_a?(String) && UUID_V7_PATTERN.match?(user_id)
    end

    raise InvalidUserId unless valid_user_ids
  end

  def validate_balance_values!
    raise InvalidBalance unless balances.each_value.all?(Integer)
  end

  def validate_zero_sum!
    raise UnbalancedBalances unless balances.each_value.sum.zero?
  end

  def settle_balances
    higher_priority = lambda do |left, right|
      amount_comparison = left.amount_cents <=> right.amount_cents
      amount_comparison.positive? ||
        (amount_comparison.zero? && left.user_id < right.user_id)
    end
    creditors = BinaryMaxHeap.new(&higher_priority)
    debtors = BinaryMaxHeap.new(&higher_priority)
    populate_heaps(creditors, debtors)

    transfers = []
    until creditors.empty? || debtors.empty?
      settle_highest_priority_pair(creditors, debtors, transfers)
    end
    transfers
  end

  def populate_heaps(creditors, debtors)
    balances.each do |user_id, balance|
      if balance.positive?
        creditors.push(BalanceEntry.new(user_id:, amount_cents: balance))
      elsif balance.negative?
        debtors.push(BalanceEntry.new(user_id:, amount_cents: -balance))
      end
    end
  end

  def settle_highest_priority_pair(creditors, debtors, transfers)
    creditor = creditors.pop
    debtor = debtors.pop
    amount_cents = [ creditor.amount_cents, debtor.amount_cents ].min

    transfers << Transfer.new(
      from_user_id: debtor.user_id,
      to_user_id: creditor.user_id,
      amount_cents:
    )

    creditor_residue = creditor.amount_cents - amount_cents
    debtor_residue = debtor.amount_cents - amount_cents
    creditors.push(creditor.with(amount_cents: creditor_residue)) if creditor_residue.positive?
    debtors.push(debtor.with(amount_cents: debtor_residue)) if debtor_residue.positive?
  end
end
