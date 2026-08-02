require "rails_helper"

RSpec.describe SettlementPlanTextPresenter do
  describe ".call" do
    it "preserva cada transferência no formato textual operacional" do
      transfers = [
        DebtSimplifier::Transfer.new(
          from_user_id: "018f0f3e-7b6c-7a10-8b2c-1234567890ab",
          to_user_id: "018f0f3e-7b6c-7a11-9b2c-1234567890ab",
          amount_cents: 300
        ),
        DebtSimplifier::Transfer.new(
          from_user_id: "018f0f3e-7b6c-7a12-ab2c-1234567890ab",
          to_user_id: "018f0f3e-7b6c-7a13-bb2c-1234567890ab",
          amount_cents: 25
        )
      ]

      expect(described_class.call(transfers)).to eq(
        [
          "018f0f3e-7b6c-7a10-8b2c-1234567890ab paga 300 centavos para 018f0f3e-7b6c-7a11-9b2c-1234567890ab",
          "018f0f3e-7b6c-7a12-ab2c-1234567890ab paga 25 centavos para 018f0f3e-7b6c-7a13-bb2c-1234567890ab"
        ]
      )
    end

    it "retorna uma lista vazia para um plano vazio" do
      expect(described_class.call([])).to eq([])
    end
  end
end
