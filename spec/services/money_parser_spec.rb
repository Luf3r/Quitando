require "rails_helper"

RSpec.describe MoneyParser do
  describe ".parse_cents" do
    it "converte texto decimal pt-BR em centavos sem float" do
      expect(described_class.parse_cents("1.234,56")).to eq(123_456)
      expect(described_class.parse_cents("12")).to eq(1_200)
      expect(described_class.parse_cents("0,01")).to eq(1)
    end

    it "preserva um valor exato acima da precisão segura de Float e dentro de bigint" do
      expect(described_class.parse_cents("90.071.992.547.409,93")).to eq(9_007_199_254_740_993)
    end

    it "demonstra que um conversor incorreto com Float perde precisão" do
      incorrect_float_converter = lambda do |value|
        (value.delete(".").tr(",", ".").to_f * 100).round
      end

      expect(incorrect_float_converter.call("90.071.992.547.409,93")).not_to eq(9_007_199_254_740_993)
      expect(described_class.parse_cents("90.071.992.547.409,93")).to eq(9_007_199_254_740_993)
    end

    it "aceita somente os agrupamentos completos definidos pela gramática pt-BR" do
      expect(described_class.parse_cents("1.234")).to eq(123_400)
      expect(described_class.parse_cents("1.234.567,89")).to eq(123_456_789)
    end

    it "rejeita valores que não são texto, espaços, sinais e casas decimais incompletas" do
      [ nil, 12, 12.34, " 12", "12 ", "+12", "12,3" ].each do |value|
        expect { described_class.parse_cents(value) }.to raise_error(MoneyParser::InvalidAmount)
      end
    end

    it "rejeita zero, zeros à esquerda, grupos incompletos e separadores ambíguos" do
      invalid_values = [
        "", "0", "00", "01", "01,00", "-1,00", "1.00", "1.23", "12.34",
        "1,234", "12,3a", "1,23,4", "1.234,56,78"
      ]

      invalid_values.each do |value|
        expect { described_class.parse_cents(value) }.to raise_error(MoneyParser::InvalidAmount)
      end
    end
  end
end
