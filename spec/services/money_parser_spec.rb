require "rails_helper"

RSpec.describe MoneyParser do
  describe ".parse_cents" do
    it "converte texto decimal pt-BR em centavos sem float" do
      expect(described_class.parse_cents("1.234,56")).to eq(123_456)
      expect(described_class.parse_cents("12")).to eq(1_200)
      expect(described_class.parse_cents("0,01")).to eq(1)
    end

    it "rejeita formatos ambíguos, negativos, zero e precisão acima de centavos" do
      [ "", "0", "-1,00", "1.00", "1,234", "12,3a", "1,23,4", 12.34 ].each do |value|
        expect { described_class.parse_cents(value) }.to raise_error(MoneyParser::InvalidAmount)
      end
    end
  end
end
