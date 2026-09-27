require "rails_helper"

RSpec.describe User do
  describe "name" do
    it "é obrigatório" do
      user = build(:user)

      user.name = nil if user.respond_to?(:name=)

      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it "normaliza espaços externos e sequências internas" do
      user = build(:user, name: "  Ana   Vitória  ")

      user.validate

      expect(user.name).to eq("Ana Vitória")
    end

    it "aceita acentos e nomes repetidos" do
      first = create(:user, name: "Ágata Conceição")
      second = build(:user, name: "Ágata Conceição")

      expect(first.name).to eq("Ágata Conceição")
      expect(second).to be_valid
    end

    it "aceita 80 caracteres e rejeita 81" do
      expect(build(:user, name: "Á" * 80)).to be_valid

      too_long = build(:user, name: "Á" * 81)

      expect(too_long).not_to be_valid
      expect(too_long.errors[:name]).to be_present
    end

    it "rejeita vazio depois da normalização" do
      user = build(:user, name: " \t  ")

      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end
  end

  describe "demo_account" do
    it "permanece imutável depois da criação" do
      user = create(:user)

      expect { user.update!(demo_account: true) }
        .to raise_error(ActiveRecord::ReadonlyAttributeError, "demo_account")

      expect(user.reload.demo_account).to be(false)
    end
  end
end
