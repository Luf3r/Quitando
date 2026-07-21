require "rails_helper"

RSpec.describe Membership do
  it "expõe a matriz exaustiva de associações obrigatórias" do
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
      user: { class_name: "User", foreign_key: "user_id", macro: :belongs_to, optional: false }
    )
  end

  it "expõe somente os mapas completos de role e status" do
    expect(described_class.defined_enums.transform_values(&:to_h)).to eq(
      "role" => { "owner" => "owner", "member" => "member" },
      "status" => { "active" => "active", "inactive" => "inactive" }
    )
  end

  it "persiste role e status válidos com UUID v7 real" do
    membership = create(:membership)

    expect(membership).to be_persisted
    expect(membership.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    expect(Membership.connection.select_value("SELECT uuid_extract_version(#{Membership.connection.quote(membership.id)}::uuid)")).to eq(7)
    expect(membership).to be_active
    expect(membership).to be_member
  end

  it "persiste owner inativo sem antecipar validações de ciclo de membership" do
    membership = create(:membership, role: :owner, status: :inactive).reload

    expect(membership).to be_persisted
    expect(membership).to be_owner
    expect(membership).to be_inactive
  end
end
