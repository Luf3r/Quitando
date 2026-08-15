require "rails_helper"

RSpec.describe GroupHistoryQuery do
  it "inclui despesas e pagamentos persistidos, mas nunca sugestões" do
    group = create(:group)
    expense = create(:expense, group:)
    payment = create(:payment, group:)

    entries = described_class.call(group:)

    expect(entries.map(&:record)).to contain_exactly(expense, payment)
    expect(entries.map(&:kind)).to contain_exactly(:expense, :payment)
  end

  it "preserva todos os estados de correção de uma despesa anulada que também substitui outra" do
    group = create(:group)
    original = create(:expense, group:)
    replacement = create(:expense, group:, replaces_expense: original, voided_at: Time.current, voided_by_user: original.created_by_user, void_reason: "Valor corrigido")

    entry = described_class.call(group:).find { |candidate| candidate.record == replacement }

    expect(entry.cycles).to contain_exactly(:voided, :replacement)
  end
end
