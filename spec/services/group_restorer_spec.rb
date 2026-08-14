require "rails_helper"

RSpec.describe GroupRestorer do
  describe ".call" do
    it "restaura grupo arquivado sem alterar moeda ou versão financeira" do
      group = create(:group, archived_at: Time.current, currency_code: "BRL")
      owner = create(:user)
      create(:membership, group:, user: owner, role: :owner, position: 0)

      restored = described_class.call(group_id: group.id, actor_user_id: owner.id)

      expect(restored).to have_attributes(archived_at: nil, currency_code: "BRL", financial_state_version: 0)
    end
  end
end
