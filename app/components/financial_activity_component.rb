class FinancialActivityComponent < ApplicationComponent
  PAYMENT_LABELS = {
    "reported" => "Declarado",
    "confirmed" => "Confirmado",
    "cancelled" => "Cancelado"
  }.freeze

  def initialize(entry:, group:, compact: false)
    @entry = entry
    @group = group
    @compact = compact
  end

  private

  attr_reader :entry, :group

  delegate :record, to: :entry

  def expense?
    entry.kind == :expense
  end

  def classes
    class_names("financial-activity", "financial-activity--compact": @compact)
  end

  def kind_label
    expense? ? "Despesa" : "Pagamento"
  end

  def description
    expense? ? record.description : "Transferência entre participantes"
  end

  def detail_path
    if expense?
      helpers.group_expense_path(group, record)
    else
      helpers.group_payment_path(group, record)
    end
  end

  def action_label
    expense? ? "Ver despesa" : "Ver detalhes"
  end

  def status
    return record.voided_at? ? "voided" : "active" if expense?

    record.status
  end

  def status_label
    return record.voided_at? ? "Anulada" : "Ativa" if expense?

    PAYMENT_LABELS.fetch(record.status)
  end
end
