require "rails_helper"
require "pbt"

RSpec.describe ProjectedBalanceCalculator, "property tests" do
  ProjectionReport = Data.define(:from_user_id, :to_user_id, :amount_cents)

  USER_IDS = [
    "018f0f3e-7b6c-7a10-8b2c-1234567890ab",
    "018f0f3e-7b6c-7a11-9b2c-1234567890ab",
    "018f0f3e-7b6c-7a12-ab2c-1234567890ab"
  ].freeze

  def balanced_official_balances(amount_cents)
    first_debt = amount_cents / 2

    {
      USER_IDS.fetch(0) => amount_cents,
      USER_IDS.fetch(1) => -first_debt,
      USER_IDS.fetch(2) => -(amount_cents - first_debt)
    }
  end

  def reports_derived_from_suggestions(official_balances, partial_selector)
    current_balances = official_balances.dup

    Array.new(2) do |position|
      transfer = DebtSimplifier.new(current_balances).call.fetch(0)
      amount_cents = if position.zero? && partial_selector.odd?
        transfer.amount_cents - 1
      else
        transfer.amount_cents
      end
      report = ProjectionReport.new(
        from_user_id: transfer.from_user_id,
        to_user_id: transfer.to_user_id,
        amount_cents:
      )

      assert_report_moves_toward_zero!(current_balances, report)
      current_balances[report.from_user_id] += report.amount_cents
      current_balances[report.to_user_id] -= report.amount_cents
      report
    end
  end

  def assert_report_moves_toward_zero!(balances, report)
    sender_before = balances.fetch(report.from_user_id)
    receiver_before = balances.fetch(report.to_user_id)

    raise "a origem não é devedora no momento do report" unless sender_before.negative?
    raise "o destino não é credor no momento do report" unless receiver_before.positive?
    raise "o report não é positivo" unless report.amount_cents.positive?
    raise "o report ultrapassa a sugestão atual" unless report.amount_cents <= sender_before.abs && report.amount_cents <= receiver_before
    raise "a origem não caminha em direção a zero" unless (sender_before + report.amount_cents).abs < sender_before.abs
    raise "o destino não caminha em direção a zero" unless (receiver_before - report.amount_cents).abs < receiver_before.abs
  end

  def assert_exactly_two_deltas_once!(projection_without_report, projection_with_report, report)
    deltas = projection_with_report.each_with_object({}) do |(user_id, balance), changed_balances|
      delta = balance - projection_without_report.fetch(user_id)
      changed_balances[user_id] = delta unless delta.zero?
    end

    expected_deltas = {
      report.from_user_id => report.amount_cents,
      report.to_user_id => -report.amount_cents
    }
    raise "o report não aplicou exatamente dois deltas uma vez" unless deltas == expected_deltas
  end

  it "preserva conservação, direção, tipos, imutabilidade e reversibilidade em 60 projeções válidas" do
    seed = Integer(ENV.fetch("PBT_SEED", "280806"))
    RSpec.configuration.reporter.message("PBT seed: #{seed}; execuções: 60; worker: none; shrinking: habilitado")

    Pbt.assert(num_runs: 60, worker: :none, seed:) do
      Pbt.property(
        Pbt.integer(min: 4, max: 10_000),
        Pbt.integer(min: 0, max: 10_000)
      ) do |amount_cents, partial_selector|
        official_balances = balanced_official_balances(amount_cents).freeze
        original_official_balances = official_balances.dup
        reports = reports_derived_from_suggestions(official_balances, partial_selector).freeze
        persisted_payment_count = Payment.count

        projected_balances = described_class.call(official_balances, reports)

        raise "o mapa oficial foi modificado" unless official_balances == original_official_balances
        raise "a projeção alterou fatos persistidos" unless Payment.count == persisted_payment_count
        raise "participante sem String" unless projected_balances.keys.all?(String)
        raise "saldo sem Integer" unless projected_balances.values.all?(Integer)
        raise "a projeção não conserva valor" unless projected_balances.values.sum.zero?
        raise "a projeção não é determinística" unless described_class.call(official_balances, reports) == projected_balances

        reports.each_index do |report_index|
          report = reports.fetch(report_index)
          reports_without_current = reports.each_with_index.filter_map do |candidate, candidate_index|
            candidate unless candidate_index == report_index
          end
          projection_without_current = described_class.call(official_balances, reports_without_current)

          assert_exactly_two_deltas_once!(projection_without_current, projected_balances, report)
        end

        projection_before_last_report = described_class.call(official_balances, reports.first(1))
        restored_projection = described_class.call(official_balances, reports.first(1))
        raise "remover o report não restaura a projeção anterior" unless restored_projection == projection_before_last_report
        raise "o último report não teve efeito observável" if projected_balances == restored_projection
      end
    end
  end

  it "detecta, com seed e shrinking, uma projeção de spec que omite o delta do destino" do
    seed = 280_807
    missing_receiver_delta_projection = lambda do |official_balances, report|
      official_balances.dup.tap { |balances| balances[report.from_user_id] += report.amount_cents }
    end

    expect do
      Pbt.assert(num_runs: 10, worker: :none, seed:) do
        Pbt.property(Pbt.integer(min: 4, max: 10_000)) do |amount_cents|
          official_balances = balanced_official_balances(amount_cents)
          report = reports_derived_from_suggestions(official_balances, 0).fetch(0)
          projection = missing_receiver_delta_projection.call(official_balances, report)

          raise "a projeção não conserva valor" unless projection.values.sum.zero?
        end
      end
    end.to raise_error(Pbt::PropertyFailure) { |error|
      expect(error.message).to include("seed: #{seed}")
      expect(error.message).to include("counterexample:")
      expect(error.message).to match(/Shrunk \d+ time/)
    }
  end
end
