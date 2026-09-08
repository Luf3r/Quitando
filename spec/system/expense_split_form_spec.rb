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

  it "invalida a confirmação quando os dados mudam e exige uma nova revisão do servidor" do
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
    expect(page).to have_css("form.expense-entry-form")

    find("#expense_amount_text").set("10,00")
    fill_in "expense_description", with: "Mercado"
    select owner.name, from: "expense_paid_by_user_id"
    click_button "Revisar divisão"
    expect(page).to have_button("Confirmar despesa", disabled: false)

    find("#expense_amount_text").set("20,00")
    expect(page).to have_text("Os dados mudaram. Revise novamente antes de confirmar.")
    expect(page).to have_button("Confirmar despesa", disabled: true)
    expect(page.find("form.expense-entry-form input[name='expense[description]']").value).to eq("Mercado")
    expect(page.find("form.expense-entry-form input[name='expense[amount_text]']").value).to eq("20,00")

    click_button "Revisar divisão"
    expect(page).to have_text("R$ 20,00")
    expect(page.find("#expense_preview [data-preview-guard-revision-value]", visible: :all)["data-preview-guard-revision-value"]).to eq(page.find("input[name='expense[preview_revision]']", visible: :all).value)
    expect(page).to have_button("Confirmar despesa", disabled: false)
  end
end
