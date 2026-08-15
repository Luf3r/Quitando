require "rails_helper"

RSpec.describe ExpenseForm do
  it "trata campos ausentes como formulário inválido" do
    expect(described_class.new).not_to be_valid
  end

  it "produz o payload de divisão igual sem converter dinheiro para float" do
    form = described_class.new(
      description: "Mercado",
      occurred_on: "2026-08-14",
      amount_text: "200,00",
      paid_by_user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b",
      split_type: "equal",
      participant_user_ids: [ "018f6d4e-06ac-7d62-8bd3-31a553f3a00b", "018f6d4e-06ac-7d62-8bd3-31a553f3a00c" ]
    )

    expect(form).to be_valid
    expect(form.command_attributes).to include(
      description: "Mercado",
      occurred_on: Date.new(2026, 8, 14),
      amount_text: "200,00",
      split: { type: :equal, participant_user_ids: form.participant_user_ids }
    )
  end

  it "produz o payload de divisão exata preservando os textos das shares" do
    shares = [
      { user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00b", amount_text: "120,00" },
      { user_id: "018f6d4e-06ac-7d62-8bd3-31a553f3a00c", amount_text: "80,00" }
    ]
    form = described_class.new(
      description: "Mercado",
      occurred_on: "2026-08-14",
      amount_text: "200,00",
      paid_by_user_id: shares.first[:user_id],
      split_type: "exact",
      participant_user_ids: [],
      shares:
    )

    expect(form).to be_valid
    expect(form.command_attributes[:split]).to eq(type: :exact, shares:)
  end
end
