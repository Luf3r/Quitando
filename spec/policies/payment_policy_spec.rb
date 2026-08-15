require "rails_helper"

RSpec.describe PaymentPolicy do
  it "permite confirmar apenas ao destino e cancelar aos participantes" do
    owner = create(:user)
    debtor = create(:user)
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: debtor, position: 1)
    payment = create(:payment, group:, from_user: debtor, to_user: owner, reported_by_user: debtor, status: :reported)

    expect(described_class.new(owner, payment)).to be_confirm
    expect(described_class.new(debtor, payment)).not_to be_confirm
    expect(described_class.new(owner, payment)).to be_cancel
    expect(described_class.new(debtor, payment)).to be_cancel
  end
end
