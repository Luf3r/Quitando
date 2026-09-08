class StatusBadgeComponent < ApplicationComponent
  LABELS = {
    "empty" => "Sem atividade",
    "open" => "Em aberto",
    "awaiting_confirmation" => "Aguardando confirmação",
    "settled" => "Quitado",
    "archived" => "Arquivado",
    "reported" => "Declarado",
    "confirmed" => "Confirmado",
    "cancelled" => "Cancelado",
    "active" => "Ativo",
    "inactive" => "Inativo",
    "voided" => "Anulada",
    "pending" => "Pendente",
    "accepted" => "Aceito",
    "declined" => "Recusado",
    "revoked" => "Revogado",
    "expired" => "Expirado",
    "owner" => "Responsável pelo grupo",
    "member" => "Membro"
  }.freeze

  TONES = {
    "open" => "attention",
    "awaiting_confirmation" => "attention",
    "reported" => "attention",
    "pending" => "attention",
    "settled" => "positive",
    "confirmed" => "positive",
    "accepted" => "positive",
    "active" => "positive",
    "cancelled" => "negative",
    "voided" => "negative",
    "declined" => "negative",
    "revoked" => "negative",
    "expired" => "negative"
  }.freeze

  def initialize(status:, label: nil)
    @status = status.to_s
    @label = label.presence || LABELS.fetch(@status)
    @tone = TONES.fetch(@status, "neutral")
  end

  private

  attr_reader :status, :label, :tone

  def classes
    "ui-badge ui-badge--#{tone}"
  end
end
