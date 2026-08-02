require "rails_helper"

RSpec.describe "ProjectedBalanceCalculator" do
  ReportedPayment = Data.define(:from_user_id, :to_user_id, :amount_cents)
  IncompleteReportedPayment = Data.define(:from_user_id, :to_user_id)

  describe ".call" do
    it "projeta o exemplo normativo de Bruno para Ana" do
      official_balances = { "ana" => 6_000, "bruno" => -3_000, "carla" => -3_000 }
      reported_payments = [ ReportedPayment.new(from_user_id: "bruno", to_user_id: "ana", amount_cents: 2_000) ]

      expect(ProjectedBalanceCalculator.call(official_balances, reported_payments)).to eq(
        "ana" => 4_000,
        "bruno" => -1_000,
        "carla" => -3_000
      )
    end

    it "aplica cada report de uma coleção múltipla exatamente uma vez" do
      official_balances = { "ana" => 6_000, "bruno" => -3_000, "carla" => -3_000 }
      reported_payments = [
        ReportedPayment.new(from_user_id: "bruno", to_user_id: "ana", amount_cents: 2_000),
        ReportedPayment.new(from_user_id: "carla", to_user_id: "ana", amount_cents: 1_000)
      ]

      expect(ProjectedBalanceCalculator.call(official_balances, reported_payments)).to eq(
        "ana" => 3_000,
        "bruno" => -1_000,
        "carla" => -2_000
      )
    end

    it "retorna uma cópia dos saldos oficiais quando não há reports" do
      official_balances = { "ana" => 2_000, "bruno" => -2_000 }

      projected_balances = ProjectedBalanceCalculator.call(official_balances, [])

      expect(projected_balances).to eq(official_balances)
      expect(projected_balances).not_to be(official_balances)
    end

    it "aceita mapa oficial e reports congelados sem modificá-los" do
      official_balances = { "ana" => 2_000, "bruno" => -2_000 }.freeze
      report = ReportedPayment.new(from_user_id: "bruno", to_user_id: "ana", amount_cents: 1_500).freeze

      expect(ProjectedBalanceCalculator.call(official_balances, [ report ].freeze)).to eq(
        "ana" => 500,
        "bruno" => -500
      )
    end

    it "preserva a soma zero dos saldos projetados" do
      official_balances = { "ana" => 5_000, "bruno" => -3_000, "carla" => -2_000 }
      reported_payments = [
        ReportedPayment.new(from_user_id: "bruno", to_user_id: "ana", amount_cents: 1_500),
        ReportedPayment.new(from_user_id: "carla", to_user_id: "ana", amount_cents: 500)
      ]

      expect(ProjectedBalanceCalculator.call(official_balances, reported_payments).values.sum).to eq(0)
    end

    it "exige a chave da origem mesmo quando o mapa oficial tem default" do
      official_balances = Hash.new(0).merge("ana" => 2_000, "bruno" => -2_000)
      report = ReportedPayment.new(from_user_id: "diego", to_user_id: "ana", amount_cents: 1_000)

      expect { ProjectedBalanceCalculator.call(official_balances, [ report ]) }
        .to raise_error(KeyError, /diego/)
    end

    it "exige a chave do destino mesmo quando o mapa oficial tem default_proc" do
      official_balances = Hash.new { |_hash, _key| 0 }.merge("ana" => 2_000, "bruno" => -2_000)
      report = ReportedPayment.new(from_user_id: "bruno", to_user_id: "diego", amount_cents: 1_000)

      expect { ProjectedBalanceCalculator.call(official_balances, [ report ]) }
        .to raise_error(KeyError, /diego/)
    end

    it "expõe o erro quando um report referencia participante ausente" do
      official_balances = { "ana" => 2_000, "bruno" => -2_000 }
      reported_payments = [ ReportedPayment.new(from_user_id: "diego", to_user_id: "ana", amount_cents: 1_000) ]

      expect { ProjectedBalanceCalculator.call(official_balances, reported_payments) }
        .to raise_error(KeyError, /diego/)
    end

    it "expõe o erro quando um report não possui amount_cents" do
      official_balances = { "ana" => 2_000, "bruno" => -2_000 }
      reported_payments = [ IncompleteReportedPayment.new(from_user_id: "bruno", to_user_id: "ana") ]

      expect { ProjectedBalanceCalculator.call(official_balances, reported_payments) }
        .to raise_error(NoMethodError, /amount_cents/)
    end
  end
end
