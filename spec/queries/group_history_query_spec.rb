require "rails_helper"

RSpec.describe GroupHistoryQuery do
  describe ".recent" do
    it "hidrata somente os fatos recentes com a mesma ordenação total do histórico" do
      group = create(:group)
      user = create(:user)
      older = create(:expense, group:, created_by_user: user, paid_by_user: user, created_at: 2.minutes.ago)
      newer_payment = create(:payment, group:, from_user: user, to_user: create(:user), created_at: 1.minute.ago)
      newest = create(:expense, group:, created_by_user: user, paid_by_user: user, created_at: Time.current)

      entries = described_class.recent(group:, limit: 2)

      expect(entries.map(&:record)).to eq([ newest, newer_payment ])
      expect(entries.map(&:record)).not_to include(older)
    end
  end

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

  it "pagina vinte e cinco fatos com ordem estável por timestamp e identificador" do
    group = create(:group)
    expenses = create_list(:expense, 26, group:, created_at: Time.zone.parse("2026-08-25 10:00:00"))

    first_page = described_class.page(group:, number: 1)
    second_page = described_class.page(group:, number: 2)

    expect(first_page).to have_attributes(number: 1, total_pages: 2, total_facts: 26)
    expect(first_page.entries.length).to eq(25)
    expect(second_page.entries.map(&:record)).to eq([ expenses.min_by(&:id) ])
  end
end
