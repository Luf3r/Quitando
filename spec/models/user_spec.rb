require "rails_helper"

RSpec.describe User do
  describe "demo_account" do
    it "permanece imutável depois da criação" do
      user = create(:user)

      expect { user.update!(demo_account: true) }
        .to raise_error(ActiveRecord::ReadonlyAttributeError, "demo_account")

      expect(user.reload.demo_account).to be(false)
    end
  end
end
