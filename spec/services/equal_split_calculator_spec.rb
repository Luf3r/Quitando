require "rails_helper"

RSpec.describe EqualSplitCalculator do
  MembershipInput = Data.define(:user_id, :position)

  def membership(user_id, position)
    MembershipInput.new(user_id:, position:)
  end

  describe ".call" do
    it "divide um total divisível em shares positivas e preserva a ordem da membership" do
      memberships = [ membership("payer", 0), membership("other", 1) ]

      expect(described_class.call(amount_cents: 10, memberships:, paid_by_user_id: "payer")).to eq(
        [
          { user_id: "payer", amount_owed_cents: 5, position: 0 },
          { user_id: "other", amount_owed_cents: 5, position: 1 }
        ]
      )
    end

    it "entrega o primeiro centavo residual ao pagador incluído e os seguintes pela posição" do
      memberships = [ membership("other", 0), membership("payer", 1), membership("third", 2) ]

      expect(described_class.call(amount_cents: 5, memberships:, paid_by_user_id: "payer")).to eq(
        [
          { user_id: "other", amount_owed_cents: 2, position: 0 },
          { user_id: "payer", amount_owed_cents: 2, position: 1 },
          { user_id: "third", amount_owed_cents: 1, position: 2 }
        ]
      )
    end

    it "distribui o residual somente pela posição quando o pagador não participa" do
      memberships = [ membership("first", 0), membership("second", 1) ]

      expect(described_class.call(amount_cents: 3, memberships:, paid_by_user_id: "payer")).to eq(
        [
          { user_id: "first", amount_owed_cents: 2, position: 0 },
          { user_id: "second", amount_owed_cents: 1, position: 1 }
        ]
      )
    end

    it "não modifica memberships recebidas" do
      memberships = [ membership("payer", 1), membership("other", 0) ].freeze
      before = Marshal.dump(memberships)

      described_class.call(amount_cents: 3, memberships:, paid_by_user_id: "payer")

      expect(Marshal.dump(memberships)).to eq(before)
    end

    it "rejeita total não positivo, participantes inválidos e posições duplicadas" do
      valid_memberships = [ membership("payer", 0) ]

      expect { described_class.call(amount_cents: 0, memberships: valid_memberships, paid_by_user_id: "payer") }
        .to raise_error(EqualSplitCalculator::InvalidSplit)
      expect { described_class.call(amount_cents: 1, memberships: [], paid_by_user_id: "payer") }
        .to raise_error(EqualSplitCalculator::InvalidSplit)
      expect do
        described_class.call(
          amount_cents: 2,
          memberships: [ membership("one", 0), membership("two", 0) ],
          paid_by_user_id: "payer"
        )
      end.to raise_error(EqualSplitCalculator::InvalidSplit)
    end

    it "rejeita total menor que a quantidade de participantes em vez de gerar share zero" do
      memberships = [ membership("payer", 0), membership("other", 1) ]

      expect { described_class.call(amount_cents: 1, memberships:, paid_by_user_id: "payer") }
        .to raise_error(EqualSplitCalculator::InvalidSplit)
    end
  end
end
