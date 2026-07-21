require "rails_helper"

RSpec.describe Membership do
  it "persiste role e status válidos com UUID v7 real" do
    membership = create(:membership)

    expect(membership).to be_persisted
    expect(membership.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    expect(Membership.connection.select_value("SELECT uuid_extract_version(#{Membership.connection.quote(membership.id)}::uuid)")).to eq(7)
    expect(membership).to be_active
    expect(membership).to be_member
  end
end
