require "rails_helper"

RSpec.describe Payment do
  it "expõe a matriz exaustiva de associações, incluindo os cinco papéis de usuário" do
    contracts = described_class.reflect_on_all_associations.to_h do |reflection|
      [
        reflection.name,
        {
          class_name: reflection.class_name,
          foreign_key: reflection.foreign_key,
          macro: reflection.macro,
          optional: reflection.options.fetch(:optional, false)
        }
      ]
    end

    expect(contracts).to eq(
      group: { class_name: "Group", foreign_key: "group_id", macro: :belongs_to, optional: false },
      from_user: { class_name: "User", foreign_key: "from_user_id", macro: :belongs_to, optional: false },
      to_user: { class_name: "User", foreign_key: "to_user_id", macro: :belongs_to, optional: false },
      reported_by_user: { class_name: "User", foreign_key: "reported_by_user_id", macro: :belongs_to, optional: false },
      confirmed_by_user: { class_name: "User", foreign_key: "confirmed_by_user_id", macro: :belongs_to, optional: true },
      cancelled_by_user: { class_name: "User", foreign_key: "cancelled_by_user_id", macro: :belongs_to, optional: true }
    )
  end

  it "expõe somente o mapa completo de status" do
    expect(described_class.defined_enums.transform_values(&:to_h)).to eq(
      "status" => { "reported" => "reported", "confirmed" => "confirmed", "cancelled" => "cancelled" }
    )
  end

  it "persiste os três estados auditáveis" do
    reported = create(:payment).reload
    confirmed = create(:payment, :confirmed).reload
    cancelled = create(:payment, :cancelled).reload

    expect(reported).to be_persisted
    expect(reported).to be_reported
    expect(reported.reported_by_user).to eq(reported.from_user)
    expect(reported.confirmed_at).to be_nil
    expect(reported.cancelled_at).to be_nil
    expect(confirmed).to be_persisted
    expect(confirmed).to be_confirmed
    expect(confirmed.confirmed_by_user).to eq(confirmed.to_user)
    expect(confirmed.confirmed_at).to be_present
    expect(confirmed.cancelled_at).to be_nil
    expect(cancelled).to be_persisted
    expect(cancelled).to be_cancelled
    expect(cancelled.cancelled_by_user).to eq(cancelled.from_user)
    expect(cancelled.cancelled_at).to be_present
    expect(cancelled.cancellation_reason).to be_present
    expect(cancelled.confirmed_at).to be_nil
  end
end
