class StatusBadgeComponent < ApplicationComponent
  LABELS = {
    "empty" => "Sem atividade",
    "open" => "Em aberto",
    "awaiting_confirmation" => "Aguardando confirmação",
    "settled" => "Quitado"
  }.freeze

  def initialize(status:)
    @label = LABELS.fetch(status.to_s)
  end
end
