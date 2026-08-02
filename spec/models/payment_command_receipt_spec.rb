require "rails_helper"

RSpec.describe PaymentCommandReceipt, type: :model do
  describe "append-only persistence" do
    it "refuses update! on a persisted receipt" do
      receipt = create(:payment_command_receipt)

      expect do
        receipt.update!(request_fingerprint: "different-fingerprint")
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "refuses destroy! on a persisted receipt" do
      receipt = create(:payment_command_receipt)

      expect do
        receipt.destroy!
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
