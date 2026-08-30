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
end
