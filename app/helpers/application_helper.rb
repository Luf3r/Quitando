module ApplicationHelper
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
end
