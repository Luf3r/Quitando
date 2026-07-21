require "rails_helper"

RSpec.describe Group do
  it "recebe UUID v7 e inicia a versão financeira em zero" do
    group = Group.create!(name: "Casa", currency_code: "BRL")

    expect(group.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    expect(group.financial_state_version).to eq(0)
    expect(Group.connection.select_value("SELECT uuid_extract_version('#{group.id}'::uuid)")).to eq(7)
  end
end
