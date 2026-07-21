require "rails_helper"

RSpec.describe Payment do
  it "persiste os três estados auditáveis" do
    reported = create(:payment)
    confirmed = create(:payment, :confirmed)
    cancelled = create(:payment, :cancelled)

    expect(reported).to be_reported
    expect(reported.reported_by_user).to eq(reported.from_user)
    expect(reported.confirmed_at).to be_nil
    expect(reported.cancelled_at).to be_nil
    expect(confirmed).to be_confirmed
    expect(confirmed.confirmed_by_user).to eq(confirmed.to_user)
    expect(confirmed.confirmed_at).to be_present
    expect(confirmed.cancelled_at).to be_nil
    expect(cancelled).to be_cancelled
    expect(cancelled.cancelled_by_user).to eq(cancelled.from_user)
    expect(cancelled.cancelled_at).to be_present
    expect(cancelled.cancellation_reason).to be_present
    expect(cancelled.confirmed_at).to be_nil
  end
end
