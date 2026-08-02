require "rails_helper"

RSpec.describe "user factory" do
  def association_contracts(model)
    model.reflect_on_all_associations.to_h do |reflection|
      optional = reflection.macro == :belongs_to ? reflection.options.fetch(:optional, false) : nil

      [
        reflection.name,
        {
          class_name: reflection.class_name,
          foreign_key: reflection.foreign_key,
          macro: reflection.macro,
          optional: optional
        }
      ]
    end
  end

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

  it "expõe a matriz exaustiva de associações por papel persistido" do
    expected_contracts = {
      memberships: { class_name: "Membership", foreign_key: "user_id", macro: :has_many, optional: nil },
      expenses_paid: { class_name: "Expense", foreign_key: "paid_by_user_id", macro: :has_many, optional: nil },
      expenses_created: { class_name: "Expense", foreign_key: "created_by_user_id", macro: :has_many, optional: nil },
      expenses_voided: { class_name: "Expense", foreign_key: "voided_by_user_id", macro: :has_many, optional: nil },
      expense_shares: { class_name: "ExpenseShare", foreign_key: "user_id", macro: :has_many, optional: nil },
      payments_sent: { class_name: "Payment", foreign_key: "from_user_id", macro: :has_many, optional: nil },
      payments_received: { class_name: "Payment", foreign_key: "to_user_id", macro: :has_many, optional: nil },
      payments_reported: { class_name: "Payment", foreign_key: "reported_by_user_id", macro: :has_many, optional: nil },
      payments_confirmed: { class_name: "Payment", foreign_key: "confirmed_by_user_id", macro: :has_many, optional: nil },
      payments_cancelled: { class_name: "Payment", foreign_key: "cancelled_by_user_id", macro: :has_many, optional: nil }
    }

    expect(association_contracts(User)).to eq(expected_contracts)
  end

  it "detecta uma matriz de reflection incompleta em controle negativo restrito à spec" do
    incomplete_contracts = association_contracts(User).except(:payments_cancelled)

    expect { expect(association_contracts(User)).to eq(incomplete_contracts) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /payments_cancelled/)
  end
end
