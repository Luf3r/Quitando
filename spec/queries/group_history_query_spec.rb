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
end
