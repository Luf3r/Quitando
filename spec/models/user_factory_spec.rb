require "rails_helper"

RSpec.describe "user factory" do
  it "cria um usuário válido" do
    user = create(:user)

    expect(user).to be_persisted
    expect(user.email).to match(/\Auser\d+@example\.com\z/)
  end

  it "delega ao PostgreSQL a geração de um UUID v7 canônico" do
    user = create(:user)
    quoted_id = User.connection.quote(user.id)

    expect(user.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    expect(User.connection.select_value("SELECT uuid_extract_version(#{quoted_id}::uuid)")).to eq(7)
  end

  it "expõe os fatos financeiros por papel persistido" do
    expected_foreign_keys = {
      expense_shares: "user_id",
      expenses_voided: "voided_by_user_id",
      payments_sent: "from_user_id",
      payments_received: "to_user_id",
      payments_reported: "reported_by_user_id",
      payments_confirmed: "confirmed_by_user_id",
      payments_cancelled: "cancelled_by_user_id"
    }

    expected_foreign_keys.each do |association_name, foreign_key|
      reflection = User.reflect_on_association(association_name)

      expect(reflection).to be_present
      expect(reflection.foreign_key).to eq(foreign_key)
    end
  end
end
