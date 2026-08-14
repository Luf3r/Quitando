require "rails_helper"

RSpec.describe MoneyFormatter do
  it "formata centavos em reais sem usar ponto flutuante" do
    expect(described_class.call(cents: 12_345, currency_code: "BRL")).to eq("R$ 123,45")
  end

  it "preserva o sinal para valores negativos" do
    expect(described_class.call(cents: -1, currency_code: "BRL")).to eq("-R$ 0,01")
  end
end
