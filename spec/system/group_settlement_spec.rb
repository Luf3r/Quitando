require "rails_helper"

RSpec.describe "Jornada de quitação do grupo" do
  before { driven_by(:rack_test) }

  it "liquida o grupo por HTML sem JavaScript" do
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    carla = create(:user, email: "carla@example.com")

    sign_in(ana)
    visit groups_path
    fill_in "group_name", with: "Apartamento"
    click_button "Criar grupo"
    group = Group.find_by!(name: "Apartamento")

    visit group_path(group)
    fill_in "invitation_email", with: bruno.email
    click_button "Enviar convite"
    fill_in "invitation_email", with: carla.email
    click_button "Enviar convite"

    sign_out
    sign_in(bruno)
    visit invitations_path
    click_button "Aceitar convite"
    sign_out
    sign_in(carla)
    visit invitations_path
    click_button "Aceitar convite"

    sign_out
    sign_in(ana)
    visit group_path(group)
    within(all('form[action="/groups/' + group.id + '/expenses"]').first) do
      fill_in "expense_description", with: "Compra de Ana"
      fill_in "expense_occurred_on", with: "2026-08-14"
      fill_in "expense_amount_text", with: "200,00"
      all('input[name="expense[participant_user_ids][]"]')[1].uncheck
      click_button "Registrar despesa"
    end

    sign_out
    sign_in(carla)
    visit group_path(group)
    forms = all('form[action="/groups/' + group.id + '/expenses"]')
    within(forms.last) do
      fill_in "expense_description", with: "Compra registrada por Carla"
      fill_in "expense_occurred_on", with: "2026-08-14"
      fill_in "expense_amount_text", with: "100,00"
      select bruno.email, from: "expense_paid_by_user_id"
      find('input[name="expense[shares][0][amount_text]"]').set("100,00")
      click_button "Registrar divisão exata"
    end

    expect(page).to have_text("pago por bruno@example.com, registrado por carla@example.com")
    expect(page).to have_text("Plano líquido")
    click_button "Reportar pagamento"
    payment_path = current_path

    sign_out
    sign_in(bruno)
    visit payment_path
    click_button "Confirmar pagamento"
    visit group_path(group)

    expect(page).to have_text("Quitado")
  end

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    find('input[type="submit"]').click
  end

  def sign_out
    click_button "Sair"
  end
end
