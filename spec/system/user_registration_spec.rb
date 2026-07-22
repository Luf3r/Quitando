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

  it "permite que uma pessoa existente inicie uma sessão" do
    user = create(:user, email: "bia@example.com")

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    find('input[type="submit"]').click

    expect(page).to have_text("Conectado como bia@example.com.")
  end

  it "não inicia sessão com credenciais inválidas" do
    user = create(:user, email: "carla@example.com")

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "senha-incorreta"
    find('input[type="submit"]').click
    visit root_path

    expect(page).to have_link("Entrar")
    expect(page).not_to have_text("Conectado como carla@example.com.")
  end
end
