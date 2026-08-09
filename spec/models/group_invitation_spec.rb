require "rails_helper"

RSpec.describe "GroupInvitation model contract" do
  it "exposes the internal-invitation associations and all terminal states" do
    expect(defined?(GroupInvitation)).to eq("constant")

    contracts = GroupInvitation.reflect_on_all_associations.to_h do |reflection|
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
      invited_user: { class_name: "User", foreign_key: "invited_user_id", macro: :belongs_to, optional: false },
      invited_by_user: { class_name: "User", foreign_key: "invited_by_user_id", macro: :belongs_to, optional: false }
    )
    expect(GroupInvitation.defined_enums.fetch("status").to_h).to eq(
      "pending" => "pending",
      "accepted" => "accepted",
      "declined" => "declined",
      "revoked" => "revoked",
      "expired" => "expired"
    )
  end

  it "persists the pending invitation factory with a PostgreSQL UUID v7" do
    invitation = create(:group_invitation)

    expect(invitation).to be_pending
    expect(invitation.expires_at).to be > Time.current
    expect(invitation.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    expect(GroupInvitation.connection.select_value("SELECT uuid_extract_version(#{GroupInvitation.connection.quote(invitation.id)}::uuid)")).to eq(7)
  end
end
