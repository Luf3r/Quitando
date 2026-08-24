require "rails_helper"

RSpec.describe DebtSimplifier do
  let(:user_id) { "018f0f3e-7b6c-7a10-8b2c-1234567890ab" }
  let(:other_user_id) { "018f0f3e-7b6c-7a11-9b2c-1234567890ab" }
  let(:third_user_id) { "018f0f3e-7b6c-7a12-ab2c-1234567890ab" }
  let(:fourth_user_id) { "018f0f3e-7b6c-7a13-bb2c-1234567890ab" }

  def expect_conservation(balances, transfers)
    total_credit = balances.each_value.select(&:positive?).sum

    expect(transfers.sum(&:amount_cents)).to eq(total_credit),
      "conservação violada: total transferido difere do crédito inicial"
  end

  def expect_quittance(balances, transfers)
    final_balances = balances.dup
    transfers.each do |transfer|
      final_balances[transfer.from_user_id] += transfer.amount_cents
      final_balances[transfer.to_user_id] -= transfer.amount_cents
    end

    expect(final_balances.values).to all(be_zero),
      "quitação violada: ao menos um saldo final permaneceu diferente de zero"
  end

  def expect_valid_transfers(balances, transfers)
    transfers.each do |transfer|
      expect(transfer).to be_a(described_class::Transfer),
        "validade violada: saída contém valor sem o tipo Transfer"
      expect(balances).to include(transfer.from_user_id, transfer.to_user_id),
        "validade violada: transferência referencia participante desconhecido"
      expect(transfer.from_user_id).not_to eq(transfer.to_user_id),
        "validade violada: origem e destino devem ser distintos"
      expect(transfer.amount_cents).to be_positive,
        "validade violada: toda transferência deve ser positiva"
    end
  end

  def expect_transfer_bound(balances, transfers)
    participant_count = balances.count { |_user_id, balance| !balance.zero? }
    maximum_transfer_count = [ participant_count - 1, 0 ].max

    expect(transfers.length).to be <= maximum_transfer_count,
      "limite violado: plano excedeu m - 1 transferências"
  end

  describe "API pública" do
    it "expõe transferências tipadas e retorna uma coleção vazia para o mapa vazio" do
      expect(described_class::Transfer).to be < Data
      expect(described_class::Transfer.members).to eq(%i[from_user_id to_user_id amount_cents])
      expect(described_class.new({}).call).to eq([])
    end

    it "expõe os tipos públicos do trace e retorna coleções vazias para o mapa vazio" do
      expect(described_class::TraceStep).to be < Data
      expect(described_class::TraceStep.members).to eq(
        %i[
          iteration
          from_user_id
          to_user_id
          amount_cents
          debtor_balance_before_cents
          creditor_balance_before_cents
          debtor_residue_cents
          creditor_residue_cents
        ]
      )
      expect(described_class::Result.members).to eq(%i[transfers trace])
      expect(described_class.new({}).call_with_trace).to eq(
        described_class::Result.new(transfers: [], trace: [])
      )
    end

    it "expõe erros de domínio distinguíveis" do
      expect(described_class::InvalidBalances).to be < StandardError
      expect(described_class::InvalidUserId).to be < StandardError
      expect(described_class::InvalidBalance).to be < StandardError
      expect(described_class::UnbalancedBalances).to be < StandardError
    end

    it "produz o plano e um trace tipado no mesmo resultado" do
      balances = { user_id => -500, other_user_id => 500 }
      transfer = described_class::Transfer.new(
        from_user_id: user_id,
        to_user_id: other_user_id,
        amount_cents: 500
      )
      trace_step = described_class::TraceStep.new(
        iteration: 1,
        from_user_id: user_id,
        to_user_id: other_user_id,
        amount_cents: 500,
        debtor_balance_before_cents: -500,
        creditor_balance_before_cents: 500,
        debtor_residue_cents: 0,
        creditor_residue_cents: 0
      )

      expect(described_class.new(balances).call_with_trace).to eq(
        described_class::Result.new(transfers: [ transfer ], trace: [ trace_step ])
      )
      expect(described_class.new(balances).call).to eq([ transfer ])
    end
  end

  describe "validação da entrada" do
    it "rejeita a estrutura antes de validar identificadores ou saldos" do
      [ nil, [], "balances" ].each do |balances|
        expect { described_class.new(balances).call }
          .to raise_error(described_class::InvalidBalances)
      end
    end

    it "rejeita uma estrutura não duplicável sem vazar seu erro incidental" do
      invalid_balances = Class.new do
        def dup
          raise "não deve duplicar uma estrutura inválida"
        end
      end.new

      expect { described_class.new(invalid_balances).call }
        .to raise_error(described_class::InvalidBalances)
    end

    it "rejeita identificadores antes de validar seus saldos" do
      invalid_user_ids = [
        1,
        "018f0f3e-7b6c-4a10-8b2c-1234567890ab",
        "018F0F3E-7B6C-7A10-8B2C-1234567890AB",
        "018f0f3e-7b6c-7a10-0b2c-1234567890ab",
        "not-a-uuid"
      ]

      invalid_user_ids.each do |invalid_user_id|
        expect { described_class.new({ invalid_user_id => "not-integer" }).call }
          .to raise_error(described_class::InvalidUserId)
      end
    end

    it "rejeita saldos que não são Integer" do
      [ "100", 1.0, nil ].each do |invalid_balance|
        expect { described_class.new({ user_id => invalid_balance }).call }
          .to raise_error(described_class::InvalidBalance)
      end
    end

    it "rejeita soma positiva ou negativa, inclusive por um centavo, sem modificar a entrada" do
      [
        { user_id => 1, other_user_id => 0 },
        { user_id => -1, other_user_id => 0 },
        { user_id => 10_000, other_user_id => -9_999 }
      ].each do |balances|
        original_balances = balances.dup

        expect { described_class.new(balances).call }
          .to raise_error(described_class::UnbalancedBalances)
        expect(balances).to eq(original_balances)
      end
    end


    it "mantém os mesmos erros públicos em call_with_trace" do
      cases = [
        [ { "invalid-id" => 0 }, described_class::InvalidUserId ],
        [ { user_id => 1.0 }, described_class::InvalidBalance ],
        [ { user_id => 1, other_user_id => 0 }, described_class::UnbalancedBalances ]
      ]

      cases.each do |balances, expected_error|
        expect { described_class.new(balances).call_with_trace }.to raise_error(expected_error)
      end
    end
  end

  describe "um devedor e um credor" do
    it "quita uma dívida de um centavo com uma transferência tipada" do
      transfer = described_class::Transfer.new(
        from_user_id: user_id,
        to_user_id: other_user_id,
        amount_cents: 1
      )

      expect(described_class.new({ user_id => -1, other_user_id => 1 }).call).to eq([ transfer ])
    end

    it "transfere integralmente um valor representativo sem usar float" do
      transfer = described_class::Transfer.new(
        from_user_id: user_id,
        to_user_id: other_user_id,
        amount_cents: 9_223_372_036_854_775
      )

      balances = {
        user_id => -9_223_372_036_854_775,
        other_user_id => 9_223_372_036_854_775
      }

      expect(described_class.new(balances).call).to eq([ transfer ])
    end
  end

  describe "saldos zero e imutabilidade" do
    it "retorna vazio quando todos os saldos são zero" do
      balances = { user_id => 0, other_user_id => 0, third_user_id => 0 }

      expect(described_class.new(balances).call).to eq([])
    end

    it "ignora saldos zero sem alterar a transferência do par quitável" do
      balances = { user_id => -500, third_user_id => 0, other_user_id => 500 }
      without_zero = { user_id => -500, other_user_id => 500 }

      expect(described_class.new(balances).call)
        .to eq(described_class.new(without_zero).call)
    end

    it "preserva uma entrada congelada no caminho de sucesso" do
      balances = { user_id => -500, third_user_id => 0, other_user_id => 500 }.freeze
      original_balances = balances.dup

      expect { described_class.new(balances).call }.not_to raise_error
      expect(balances).to eq(original_balances)
    end

    it "preserva uma entrada congelada no caminho de erro" do
      balances = { user_id => -500, other_user_id => 499 }.freeze
      original_balances = balances.dup

      expect { described_class.new(balances).call }
        .to raise_error(described_class::UnbalancedBalances)
      expect(balances).to eq(original_balances)
    end

    it "usa uma cópia dos saldos recebidos na inicialização" do
      balances = { user_id => -500, other_user_id => 500 }
      simplifier = described_class.new(balances)
      balances[user_id] = 0
      balances[other_user_id] = 0

      expect(simplifier.call).to eq(
        [
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: other_user_id,
            amount_cents: 500
          )
        ]
      )
    end
  end

  describe "múltiplos credores e devedores" do
    it "quita dois devedores contra um credor, reinserindo o crédito residual" do
      balances = {
        user_id => -700,
        other_user_id => -300,
        third_user_id => 1_000
      }

      expect(described_class.new(balances).call).to eq(
        [
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: third_user_id,
            amount_cents: 700
          ),
          described_class::Transfer.new(
            from_user_id: other_user_id,
            to_user_id: third_user_id,
            amount_cents: 300
          )
        ]
      )
    end

    it "liquida parcialmente dívida e crédito até quitar os dois lados" do
      balances = {
        user_id => -700,
        other_user_id => -300,
        third_user_id => 600,
        fourth_user_id => 400
      }

      expect(described_class.new(balances).call).to eq(
        [
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: third_user_id,
            amount_cents: 600
          ),
          described_class::Transfer.new(
            from_user_id: other_user_id,
            to_user_id: fourth_user_id,
            amount_cents: 300
          ),
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: fourth_user_id,
            amount_cents: 100
          )
        ]
      )
    end


    it "registra saldos anteriores e resíduos assinados em cada iteração" do
      balances = {
        user_id => -700,
        other_user_id => -300,
        third_user_id => 600,
        fourth_user_id => 400
      }

      result = described_class.new(balances).call_with_trace

      expect(result.transfers).to eq(described_class.new(balances).call)
      expect(result.trace).to eq(
        [
          described_class::TraceStep.new(
            iteration: 1,
            from_user_id: user_id,
            to_user_id: third_user_id,
            amount_cents: 600,
            debtor_balance_before_cents: -700,
            creditor_balance_before_cents: 600,
            debtor_residue_cents: -100,
            creditor_residue_cents: 0
          ),
          described_class::TraceStep.new(
            iteration: 2,
            from_user_id: other_user_id,
            to_user_id: fourth_user_id,
            amount_cents: 300,
            debtor_balance_before_cents: -300,
            creditor_balance_before_cents: 400,
            debtor_residue_cents: 0,
            creditor_residue_cents: 100
          ),
          described_class::TraceStep.new(
            iteration: 3,
            from_user_id: user_id,
            to_user_id: fourth_user_id,
            amount_cents: 100,
            debtor_balance_before_cents: -100,
            creditor_balance_before_cents: 100,
            debtor_residue_cents: 0,
            creditor_residue_cents: 0
          )
        ]
      )
    end


    it "produz transferências e trace em uma única passagem do solver" do
      instrumented_simplifier_class = Class.new(described_class) do
        attr_reader :settled_pair_count

        private

        def settle_highest_priority_pair(...)
          @settled_pair_count = settled_pair_count.to_i + 1
          super
        end
      end
      simplifier = instrumented_simplifier_class.new(
        user_id => -700,
        other_user_id => -300,
        third_user_id => 600,
        fourth_user_id => 400
      )

      result = simplifier.call_with_trace

      expect(simplifier.settled_pair_count).to eq(result.transfers.length)
      expect(result.trace.length).to eq(result.transfers.length)
    end
  end

  describe "desempate determinístico" do
    it "prioriza o menor UUID quando devedores de mesma magnitude disputam um credor" do
      balances = {
        other_user_id => -500,
        user_id => -500,
        third_user_id => 1_000
      }

      expect(described_class.new(balances).call).to eq(
        [
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: third_user_id,
            amount_cents: 500
          ),
          described_class::Transfer.new(
            from_user_id: other_user_id,
            to_user_id: third_user_id,
            amount_cents: 500
          )
        ]
      )
    end

    it "prioriza o menor UUID quando credores de mesma magnitude disputam um devedor" do
      balances = {
        user_id => -1_000,
        fourth_user_id => 500,
        third_user_id => 500
      }

      expect(described_class.new(balances).call).to eq(
        [
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: third_user_id,
            amount_cents: 500
          ),
          described_class::Transfer.new(
            from_user_id: user_id,
            to_user_id: fourth_user_id,
            amount_cents: 500
          )
        ]
      )
    end

    it "produz as mesmas transferências para permutações equivalentes" do
      canonical_balances = {
        user_id => -500,
        other_user_id => -500,
        third_user_id => 500,
        fourth_user_id => 500
      }
      permuted_balances = {
        fourth_user_id => 500,
        other_user_id => -500,
        third_user_id => 500,
        user_id => -500
      }
      expected_transfers = [
        described_class::Transfer.new(
          from_user_id: user_id,
          to_user_id: third_user_id,
          amount_cents: 500
        ),
        described_class::Transfer.new(
          from_user_id: other_user_id,
          to_user_id: fourth_user_id,
          amount_cents: 500
        )
      ]

      expect(described_class.new(canonical_balances).call).to eq(expected_transfers)
      expect(described_class.new(permuted_balances).call).to eq(expected_transfers)
    end


    it "produz o mesmo trace para permutações equivalentes" do
      canonical_balances = {
        user_id => -500,
        other_user_id => -500,
        third_user_id => 500,
        fourth_user_id => 500
      }
      permuted_balances = canonical_balances.to_a.reverse.to_h

      canonical_result = described_class.new(canonical_balances.freeze).call_with_trace
      permuted_result = described_class.new(permuted_balances.freeze).call_with_trace

      expect(permuted_result).to eq(canonical_result)
      expect(canonical_result.transfers).to eq(described_class.new(canonical_balances).call)
    end
  end

  describe "invariantes globais" do
    it "conserva o valor, quita os saldos e respeita o limite m - 1" do
      valid_cases = [
        {},
        { user_id => 0, other_user_id => 0 },
        { user_id => -1, other_user_id => 1 },
        {
          user_id => -700,
          other_user_id => -300,
          third_user_id => 600,
          fourth_user_id => 400
        }
      ]

      valid_cases.each do |balances|
        frozen_balances = balances.freeze
        original_balances = balances.dup
        transfers = described_class.new(frozen_balances).call

        expect_conservation(frozen_balances, transfers)
        expect_quittance(frozen_balances, transfers)
        expect_valid_transfers(frozen_balances, transfers)
        expect_transfer_bound(frozen_balances, transfers)
        expect(frozen_balances).to eq(original_balances)
        expect(described_class.new(frozen_balances).call).to eq(transfers)
      end
    end

    it "detecta controles negativos específicos sem mutar código de produção" do
      balances = { user_id => -500, other_user_id => 500 }
      valid_transfer = described_class::Transfer.new(
        from_user_id: user_id,
        to_user_id: other_user_id,
        amount_cents: 500
      )
      incomplete_transfer = valid_transfer.with(amount_cents: 499)
      invalid_transfer = valid_transfer.with(amount_cents: 0)

      expect { expect_conservation(balances, [ incomplete_transfer ]) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /conservação violada/)
      expect { expect_quittance(balances, []) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /quitação violada/)
      expect { expect_valid_transfers(balances, [ invalid_transfer ]) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /validade violada/)
      expect { expect_transfer_bound(balances, [ valid_transfer, valid_transfer ]) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /limite violado/)
    end
  end
end
