require "rails_helper"

RSpec.describe "Navegação compacta do grupo", type: :system do
  before { driven_by(:chrome_headless) }

  after do
    page.current_window.resize_to(1400, 1400)
    Capybara.reset_sessions!
  end

  it "usa uma grade de duas colunas sem estourar o viewport móvel" do
    user = create(:user, email: "ana@example.com")
    group = GroupCreator.call(owner_user_id: user.id, name: "Apartamento")
    page.current_window.resize_to(360, 844)

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "senha-segura"
    click_button "Entrar"
    expect(page).to have_current_path(root_path)
    visit group_path(group)
    expect(page).to have_current_path(group_path(group))

    navigation = page.find("nav.group-navigation")
    expect(page.evaluate_script("getComputedStyle(arguments[0]).gridTemplateColumns", navigation)).to match(/\S+\s+\S+/)
    expect(page.evaluate_script("arguments[0].getBoundingClientRect().right <= document.documentElement.clientWidth", navigation)).to be(true)
    expect(navigation).to have_link("Configurações")
  end

  it "abre o menu nativo e mantém os destinos da navegação global em 360 px" do
    user = create(:user, email: "ana@example.com")
    page.current_window.resize_to(360, 844)

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "senha-segura"
    click_button "Entrar"

    menu = page.find("details.site-navigation__mobile")
    expect(page.evaluate_script("arguments[0].open", menu)).to be(false)
    menu.find("summary").click
    expect(page.evaluate_script("arguments[0].open", menu)).to be(true)
    panel = menu.find(".site-navigation__mobile-panel", visible: :all)
    expect(page.evaluate_script("getComputedStyle(arguments[0]).display", panel)).not_to eq("none")
    expect(menu).to have_link("Grupos", href: groups_path, visible: :all)
    expect(menu).to have_link("Conta", href: "/account", visible: :all)
  end
end
