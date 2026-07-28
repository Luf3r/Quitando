class EqualSplitCalculator
  class InvalidSplit < ArgumentError; end

  def self.call(amount_cents:, memberships:, paid_by_user_id:)
    new(amount_cents:, memberships:, paid_by_user_id:).call
  end

  def initialize(amount_cents:, memberships:, paid_by_user_id:)
    @amount_cents = amount_cents
    @memberships = memberships
    @paid_by_user_id = paid_by_user_id
  end

  def call
    validate!

    base_amount, residual = amount_cents.divmod(ordered_memberships.length)
    residual_recipient_ids = residual_order.first(residual).map(&:user_id)

    ordered_memberships.map do |membership|
      {
        user_id: membership.user_id,
        amount_owed_cents: base_amount + (residual_recipient_ids.include?(membership.user_id) ? 1 : 0),
        position: membership.position
      }
    end
  end

  private

  attr_reader :amount_cents, :memberships, :paid_by_user_id

  def validate!
    raise InvalidSplit, "valor deve ser um inteiro positivo" unless amount_cents.is_a?(Integer) && amount_cents.positive?
    raise InvalidSplit, "participantes devem ser uma coleção não vazia" unless memberships.is_a?(Array) && memberships.any?
    raise InvalidSplit, "pagador deve ser identificado" unless valid_user_id?(paid_by_user_id)
    raise InvalidSplit, "membership inválida" unless memberships.all? { |membership| valid_membership?(membership) }
    raise InvalidSplit, "participantes duplicados" unless memberships.map(&:user_id).uniq.length == memberships.length
    raise InvalidSplit, "posições duplicadas" unless memberships.map(&:position).uniq.length == memberships.length
    raise InvalidSplit, "valor insuficiente para shares positivas" if amount_cents < memberships.length
  end

  def valid_membership?(membership)
    membership.respond_to?(:user_id) && membership.respond_to?(:position) &&
      valid_user_id?(membership.user_id) &&
      membership.position.is_a?(Integer) && membership.position >= 0
  end

  def valid_user_id?(user_id)
    user_id.is_a?(String) && !user_id.strip.empty?
  end

  def ordered_memberships
    @ordered_memberships ||= memberships.sort_by(&:position)
  end

  def residual_order
    payer, others = ordered_memberships.partition { |membership| membership.user_id == paid_by_user_id }
    payer + others
  end
end
