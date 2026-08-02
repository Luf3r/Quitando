require "rails_helper"

RSpec.describe ExpenseShare do
  it "expõe a matriz exaustiva de associações obrigatórias" do
    contracts = described_class.reflect_on_all_associations.to_h do |reflection|
      [
        reflection.name,
        {
          class_name: reflection.class_name,
          foreign_key: reflection.foreign_key,
          macro: reflection.macro,
          optional: reflection.options.fetch(:optional, false)
        }
      ]
    end

    expect(contracts).to eq(
      expense: { class_name: "Expense", foreign_key: "expense_id", macro: :belongs_to, optional: false },
      user: { class_name: "User", foreign_key: "user_id", macro: :belongs_to, optional: false }
    )
  end

  it "persiste share positiva com posição e UUID v7 real" do
    share = create(:expense_share)

    expect(share).to be_persisted
    expect(share.position).to eq(0)
    expect(share.amount_owed_cents).to be_positive
    expect(ExpenseShare.connection.select_value("SELECT uuid_extract_version(#{ExpenseShare.connection.quote(share.id)}::uuid)")).to eq(7)
  end
end
