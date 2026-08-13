class PaymentConfirmer < PaymentCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, payment_id:, actor_user_id:, idempotency_key:)
    @group_id = group_id
    @payment_id = payment_id
    @actor_user_id = actor_user_id
    @idempotency_key = idempotency_key
  end

  def call
    validate_persisted_ids!(group_id, payment_id, actor_user_id)
    validate_idempotency_key!(idempotency_key)
    request_fingerprint = fingerprint([ "v1", "confirm", group_id, payment_id, actor_user_id ])

    perform_idempotent_command(idempotency_key, request_fingerprint) do
      Group.transaction do
        group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
        raise Forbidden, "membership ativa obrigatória" unless active_member?(group, actor_user_id)
        previous = resolve_receipt!(idempotency_key, request_fingerprint)
        return previous if previous

        raise ArchivedGroup, "grupo arquivado" if group.archived_at?
        payment = group.payments.lock.find_by(id: payment_id) || raise(NotFound, "pagamento não encontrado")
        raise Forbidden, "somente o destino confirma" unless payment.to_user_id == actor_user_id
        raise InvalidTransition, payment.status unless payment.reported?

        payment.update!(status: :confirmed, confirmed_by_user_id: actor_user_id, confirmed_at: Time.current)
        FinancialCommandReceipt.create!(payment:, command_type: :confirm, idempotency_key:, request_fingerprint:)
        group.increment!(:financial_state_version)
        publish("quitando.payment.confirmed", payment:, actor_user_id:, financial_state_version: group.financial_state_version)
        payment
      end
    end
  end

  private

  attr_reader :group_id, :payment_id, :actor_user_id, :idempotency_key
end
