require "rails_helper"

RSpec.describe "User registration" do
  before { driven_by(:rack_test) }

  it "permite criar uma conta e iniciar uma sessão" do
    visit new_user_registration_path

    fill_in "user_email", with: "ana@example.com"
    fill_in "user_password", with: "senha-segura"
    fill_in "user_password_confirmation", with: "senha-segura"
    find('input[type="submit"]').click

    expect(page).to have_text("Conectado como ana@example.com.")
  end
end
