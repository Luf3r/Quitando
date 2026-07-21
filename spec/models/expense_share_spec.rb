require "rails_helper"

RSpec.describe ExpenseShare do
  it "persiste share positiva com posição e UUID v7 real" do
    share = create(:expense_share)

    expect(share).to be_persisted
    expect(share.position).to eq(0)
    expect(share.amount_owed_cents).to be_positive
    expect(ExpenseShare.connection.select_value("SELECT uuid_extract_version(#{ExpenseShare.connection.quote(share.id)}::uuid)")).to eq(7)
  end
end
