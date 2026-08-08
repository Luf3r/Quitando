class PaymentReporter < PaymentCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, actor_user_id:, from_user_id:, to_user_id:, amount_text:, expected_financial_state_version:, idempotency_key:)
    @group_id = group_id
    @actor_user_id = actor_user_id
    @from_user_id = from_user_id
    @to_user_id = to_user_id
    @amount_text = amount_text
    @expected_financial_state_version = expected_financial_state_version
    @idempotency_key = idempotency_key
  end

  def call
    validate_persisted_ids!(group_id, actor_user_id, from_user_id, to_user_id)
    validate_idempotency_key!(idempotency_key)
    validate_expected_version!(expected_financial_state_version)
    amount_cents = MoneyParser.parse_cents(amount_text)
    request_fingerprint = fingerprint([ "v1", "report", group_id, actor_user_id, from_user_id, to_user_id, amount_cents, expected_financial_state_version ])

    perform_idempotent_command(idempotency_key, request_fingerprint) do
      Group.transaction do
        group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
        raise Forbidden, "membership ativa obrigatória" unless active_member?(group, actor_user_id)

        previous = resolve_receipt!(idempotency_key, request_fingerprint)
        return previous if previous

        raise ArchivedGroup, "grupo arquivado" if group.archived_at?
        raise Forbidden, "somente a origem reporta" unless actor_user_id == from_user_id
        raise Forbidden, "membership ativa obrigatória" unless active_member?(group, from_user_id) && active_member?(group, to_user_id)
        plan = SettlementPlanGenerator.call(group)
        if group.financial_state_version != expected_financial_state_version
          raise StaleFinancialState.new(financial_state_version: group.financial_state_version, plan:)
        end
        suggestion = plan.find { |transfer| transfer.from_user_id == from_user_id && transfer.to_user_id == to_user_id }
        raise SuggestionUnavailable, "sugestão indisponível" unless suggestion && amount_cents <= suggestion.amount_cents

        payment = Payment.create!(
          group:,
          from_user_id:,
          to_user_id:,
          amount_cents:,
          status: :reported,
          idempotency_key:,
          request_fingerprint:,
          source_financial_state_version: expected_financial_state_version,
          reported_by_user_id: actor_user_id,
          reported_at: Time.current
        )
        FinancialCommandReceipt.create!(payment:, command_type: :report, idempotency_key:, request_fingerprint:)
        group.increment!(:financial_state_version)
        publish("quitando.payment.reported", payment:, actor_user_id:, financial_state_version: group.financial_state_version)
        payment
      end
    end
  rescue MoneyParser::InvalidAmount => error
    raise InvalidInput, error.message, cause: nil
  end

  private

  attr_reader :group_id, :actor_user_id, :from_user_id, :to_user_id, :amount_text, :expected_financial_state_version, :idempotency_key
end
