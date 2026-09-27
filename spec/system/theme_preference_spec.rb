require "rails_helper"

RSpec.describe "Preferência de tema", type: :system do
  before { driven_by(:chrome_headless) }

  after do
    page.execute_script("localStorage.removeItem('quitando.theme')")
    Capybara.reset_sessions!
  end

  it "persiste override claro ou escuro e descarta valor inválido" do
    visit root_path

    expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("system")
    select "Escuro", from: "Tema"
    expect(page.evaluate_script("localStorage.getItem('quitando.theme')")).to eq("dark")
    expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("dark")

    refresh
    expect(page).to have_select("Tema", selected: "Escuro")

    page.execute_script("localStorage.setItem('quitando.theme', 'invalido')")
    visit root_path
    expect(page.evaluate_script("localStorage.getItem('quitando.theme')")).to be_nil
    expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("system")
    expect(page).to have_select("Tema", selected: "Sistema")
  end
end
