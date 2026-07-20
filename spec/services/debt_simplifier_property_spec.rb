require "rails_helper"
require "pbt"

RSpec.describe DebtSimplifier, "property tests" do
  USER_IDS = [
    "018f0f3e-7b6c-7a10-8b2c-1234567890ab",
    "018f0f3e-7b6c-7a11-9b2c-1234567890ab",
    "018f0f3e-7b6c-7a12-ab2c-1234567890ab",
    "018f0f3e-7b6c-7a13-bb2c-1234567890ab",
    "018f0f3e-7b6c-7a14-8b2c-1234567890ab",
    "018f0f3e-7b6c-7a15-9b2c-1234567890ab",
    "018f0f3e-7b6c-7a16-ab2c-1234567890ab",
    "018f0f3e-7b6c-7a17-bb2c-1234567890ab",
    "018f0f3e-7b6c-7a18-8b2c-1234567890ab"
  ].freeze

  def zero_sum_balances(generated_balances)
    return {} if generated_balances.empty?

    generated_balances.each_with_index.to_h do |balance, index|
      [ USER_IDS.fetch(index), balance ]
    end.tap do |balances|
      balances[USER_IDS.fetch(generated_balances.length)] = -balances.each_value.sum
    end
  end

  def verify_invariants!(balances, transfers)
    original_balances = balances.dup
    participant_count = balances.count { |_user_id, balance| !balance.zero? }
    maximum_transfer_count = [ participant_count - 1, 0 ].max

    raise "a entrada foi modificada" unless balances == original_balances
    raise "o plano excedeu m - 1" unless transfers.length <= maximum_transfer_count

    transfers.each do |transfer|
      raise "a saída contém valor sem tipo Transfer" unless transfer.is_a?(described_class::Transfer)
      raise "a transferência referencia participante desconhecido" unless balances.key?(transfer.from_user_id)
      raise "a transferência referencia participante desconhecido" unless balances.key?(transfer.to_user_id)
      raise "a transferência possui origem e destino iguais" if transfer.from_user_id == transfer.to_user_id
      raise "a transferência não é positiva" unless transfer.amount_cents.positive?
    end

    total_credit = balances.each_value.select(&:positive?).sum
    raise "o valor não foi conservado" unless transfers.sum(&:amount_cents) == total_credit

    final_balances = balances.dup
    transfers.each do |transfer|
      final_balances[transfer.from_user_id] += transfer.amount_cents
      final_balances[transfer.to_user_id] -= transfer.amount_cents
    end
    raise "os saldos não foram quitados" unless final_balances.each_value.all?(&:zero?)
  end

  it "preserva os invariantes em 250 mapas válidos, sem filtrar casos" do
    seed = Integer(ENV.fetch("PBT_SEED", "270719"))
    arbitrary_balances = Pbt.array(
      Pbt.integer(min: -10_000, max: 10_000),
      max: USER_IDS.length - 1,
      empty: true
    )
    RSpec.configuration.reporter.message(
      "PBT seed: #{seed}; execuções: 250; worker: none; shrinking: habilitado"
    )

    Pbt.assert(num_runs: 250, worker: :none, seed:) do
      Pbt.property(arbitrary_balances) do |generated_balances|
        balances = zero_sum_balances(generated_balances).freeze
        original_balances = balances.dup
        transfers = described_class.new(balances).call

        verify_invariants!(balances, transfers)
        raise "a entrada foi modificada" unless balances == original_balances
        raise "a saída não é determinística" unless described_class.new(balances).call == transfers

        permuted_balances = balances.to_a.reverse.to_h.freeze
        raise "uma permutação alterou a saída" unless described_class.new(permuted_balances).call == transfers
      end
    end
  end

  it "reporta seed, contraexemplo e shrinking para uma função incorreta" do
    seed = 27_072
    empty_plan = ->(_balances) { [] }

    expect do
      Pbt.assert(num_runs: 10, worker: :none, seed:) do
        Pbt.property(Pbt.integer(min: 2, max: 10_000)) do |amount_cents|
          balances = {
            USER_IDS.fetch(0) => -amount_cents,
            USER_IDS.fetch(1) => amount_cents
          }
          verify_invariants!(balances, empty_plan.call(balances))
        end
      end
    end.to raise_error(Pbt::PropertyFailure) { |error|
      expect(error.message).to include("seed: #{seed}")
      expect(error.message).to include("counterexample:")
      expect(error.message).to match(/Shrunk \d+ time/)
    }
  end
end
