module ApplicationHelper
  def payment_status_label(status)
    { "reported" => "declarado", "confirmed" => "confirmado", "cancelled" => "cancelado" }.fetch(status.to_s)
  end
end
