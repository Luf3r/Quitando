require "rails_helper"

RSpec.describe "Resumo e configurações do grupo", type: :system do
  before { driven_by(:chrome_headless) }

  it "separa visualmente origem, conector e destino no resumo" do
    owner = create(:user, name: "Diego", email: "diego-summary-layout@example.com")
    member = create(:user, name: "Bruno", email: "bruno-summary-layout@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    create(:payment, group:, from_user: member, to_user: owner, reported_by_user: member, status: :reported, amount_cents: 100)

    sign_in(member)
    visit group_path(group)

    parties = find(".operational-list__parties")
    expect(parties).to have_css(".operational-list__connector", text: "para")
    expect(page.evaluate_script("arguments[0].textContent", parties)).to eq("Bruno para Diego")
    expect(page.evaluate_script("getComputedStyle(arguments[0]).gap", parties)).not_to eq("normal")
  end

  it "mantém o motivo de bloqueio abaixo das ações do membro" do
    owner = create(:user, email: "ana-settings-layout@example.com")
    member = create(:user, email: "bia-settings-layout@example.com")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Apartamento")
    create(:membership, group:, user: member, position: 1)
    expense = create(:expense, group:, paid_by_user: owner, created_by_user: owner, amount_cents: 300)
    create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)

    sign_in(owner)
    visit group_settings_path(group)

    member_row = find(".settings-member", text: member.email)
    feedback = member_row.find(".settings-record__feedback", text: "saldo oficial diferente de zero")
    actions = member_row.find(".settings-record__actions")
    feedback_top = page.evaluate_script("arguments[0].getBoundingClientRect().top", feedback)
    actions_bottom = page.evaluate_script("arguments[0].getBoundingClientRect().bottom", actions)
    expect(feedback_top).to be >= actions_bottom
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button "Entrar"
    expect(page).to have_current_path(root_path)
  end
end
