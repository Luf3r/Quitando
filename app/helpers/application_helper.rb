module ApplicationHelper
  DEMO_RESET_INTERVAL = 6.hours

  def payment_status_label(status)
    { "reported" => "declarado", "confirmed" => "confirmado", "cancelled" => "cancelado" }.fetch(status.to_s)
  end

  def invitation_status_label(status)
    {
      "pending" => "Pendente",
      "accepted" => "Aceito",
      "declined" => "Recusado",
      "revoked" => "Revogado",
      "expired" => "Expirado"
    }.fetch(status.to_s)
  end

  def invitation_terminal_at(invitation)
    invitation.accepted_at || invitation.declined_at || invitation.revoked_at || invitation.expired_at
  end

  def demo_mode?
    ENV["QUITANDO_DEMO_MODE"] == "true"
  end

  def demo_public_password
    ENV["QUITANDO_DEMO_PASSWORD"]
  end

  def demo_public_emails
    DemoScenario::Installer::PUBLIC_ACCOUNTS.values
  end

  def demo_next_reset_at
    scenario = DemoScenario.find_by!(key: DemoScenario::Installer::SCENARIO_KEY)
    scenario.last_reset_at + DEMO_RESET_INTERVAL
  end

  def participant_summary(memberships)
    participants = memberships.map { |membership| membership.user.email }
    return participants.to_sentence(two_words_connector: " e ", last_word_connector: ", e ") if participants.length <= 3

    "#{participants.first(2).to_sentence(two_words_connector: " e ")} e mais #{participants.length - 2}"
  end

  def group_card_attention_message(card)
    return "Grupo arquivado. A leitura permanece disponível." if card.archived
    return "Você tem #{card.pending_received_count} #{card.pending_received_count == 1 ? "pagamento" : "pagamentos"} para revisar." if card.pending_received_count.positive?
    return "Você marcou #{card.pending_sent_count} #{card.pending_sent_count == 1 ? "pagamento" : "pagamentos"} como enviado." if card.pending_sent_count.positive?

    if card.viewer_balance_cents.positive?
      return "Você deve receber #{MoneyFormatter.call(cents: card.viewer_balance_cents, currency_code: card.group.currency_code)}."
    end

    if card.viewer_balance_cents.negative?
      return "Você precisa enviar #{MoneyFormatter.call(cents: -card.viewer_balance_cents, currency_code: card.group.currency_code)}."
    end

    return "Aguardando outras pessoas agirem." if card.attention_rank == 4
    return "Adicione a primeira despesa." if card.status == :empty

    "Este grupo está quitado."
  end
end
