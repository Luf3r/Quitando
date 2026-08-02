require "rails_helper"

RSpec.describe Group do
  it "expõe a matriz exaustiva de associações" do
    contracts = described_class.reflect_on_all_associations.to_h do |reflection|
      [
        reflection.name,
        {
          class_name: reflection.class_name,
          foreign_key: reflection.foreign_key,
          macro: reflection.macro,
          optional: nil
        }
      ]
    end

    expect(contracts).to eq(
      memberships: { class_name: "Membership", foreign_key: "group_id", macro: :has_many, optional: nil },
      expenses: { class_name: "Expense", foreign_key: "group_id", macro: :has_many, optional: nil },
      payments: { class_name: "Payment", foreign_key: "group_id", macro: :has_many, optional: nil }
    )
  end

  it "recebe UUID v7 e inicia a versão financeira em zero" do
    group = Group.create!(name: "Casa", currency_code: "BRL")

    expect(group.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    expect(group.financial_state_version).to eq(0)
    expect(Group.connection.select_value("SELECT uuid_extract_version('#{group.id}'::uuid)")).to eq(7)
  end
end
