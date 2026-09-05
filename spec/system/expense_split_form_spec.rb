require "rails_helper"

RSpec.describe "Divisão de despesa", type: :system do
  before { driven_by(:chrome_headless) }

  after do
    page.current_window.resize_to(1400, 1400)
    Capybara.reset_sessions!
  end

  it "alterna somente a apresentação da divisão escolhida" do
    owner = create(:user, email: "ana@example.com")
    member = create(:user, email: "bia@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)

    visit new_user_session_path
    fill_in "user_email", with: owner.email
    fill_in "user_password", with: "senha-segura"
    click_button "Entrar"
    expect(page).to have_current_path(root_path)
    visit new_group_expense_path(group)
    expect(page).to have_current_path(new_group_expense_path(group))
    expect(page).to have_css("h1", text: "Nova despesa")

    equal = page.find("fieldset", text: "Participantes da divisão igual", visible: :all)
    exact = page.find("fieldset", text: "Valores exatos", visible: :all)
    expect(page.evaluate_script("arguments[0].hidden", equal)).to be(false)
    expect(page.evaluate_script("arguments[0].hidden", exact)).to be(true)

    choose "Informar valores exatos"

    expect(page.evaluate_script("arguments[0].hidden", equal)).to be(true)
    expect(page.evaluate_script("arguments[0].hidden", exact)).to be(false)
  end
end
