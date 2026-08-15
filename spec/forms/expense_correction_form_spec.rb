require "rails_helper"

RSpec.describe ExpenseCorrectionForm do
  it "trata campos ausentes como formulário inválido" do
    expect(described_class.new).not_to be_valid
  end

  it "produz o comando de correção com versão financeira inteira" do
    form = described_class.new(
      reason: "Valor correto",
      expected_financial_state_version: "4",
      idempotency_key: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
      description: "Mercado",
      occurred_on: Date.new(2026, 8, 14),
      amount_text: "25,00",
      paid_by_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c",
      split_type: "equal",
      participant_user_ids: [ "018f6d4e-06ac-7d62-8bd3-31a553f3a00c", "018f6d4e-06ac-7d62-8bd3-31a553f3a00d" ]
    )

    expect(form).to be_valid
    expect(form.command_attributes).to include(
      reason: "Valor correto",
      expected_financial_state_version: 4,
      idempotency_key: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
      occurred_on: Date.new(2026, 8, 14)
    )
  end

  it "rejeita uma versão financeira que não seja inteiro não negativo" do
    form = described_class.new(
      reason: "Valor correto",
      expected_financial_state_version: "4.0",
      idempotency_key: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
      description: "Mercado",
      occurred_on: Date.new(2026, 8, 14),
      amount_text: "25,00",
      paid_by_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c",
      split_type: "equal",
      participant_user_ids: [ "018f6d4e-06ac-7d62-8bd3-31a553f3a00c" ]
    )

    expect(form).not_to be_valid
  end
end
