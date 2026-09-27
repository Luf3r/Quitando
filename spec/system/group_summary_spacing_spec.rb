require "rails_helper"

RSpec.describe "Espaçamento do resumo financeiro", type: :system do
  before { driven_by(:chrome_headless) }

  after do
    page.current_window.resize_to(1400, 1000)
    Capybara.reset_sessions!
  end

  it "separa a próxima ação e as listas de pendências dos seus títulos" do
    fixture = create_fixture!

    sign_in(fixture.fetch(:member))
    visit group_path(fixture.fetch(:group))

    [ [ 360, 844 ], [ 1400, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)

      spacing = page.evaluate_script(<<~JS)
        (() => {
          const distance = (before, after) => after.getBoundingClientRect().top - before.getBoundingClientRect().bottom
          return {
            nextAction: distance(
              document.querySelector("#group_next_action p"),
              document.querySelector("#group_next_action .ui-button")
            ),
            waiting: distance(
              document.querySelector("#waiting-pending-title"),
              document.querySelector("#waiting-pending-title + .operational-list")
            ),
            participants: distance(
              document.querySelector("#participants-title"),
              document.querySelector("#participants-title + .participant-balances")
            )
          }
        })()
      JS

      expect(spacing.values).to all(be >= 12)
    end
  end

  private

  def create_fixture!
    owner = create(:user, name: "Ana", password: "senha-segura", password_confirmation: "senha-segura")
    member = create(:user, name: "Bruno", password: "senha-segura", password_confirmation: "senha-segura")
    group = GroupCreator.call(owner_user_id: owner.id, name: "Resumo com espaçamento")
    create(:membership, group:, user: member, position: 1)

    expense = create(:expense, group:, paid_by_user: owner, created_by_user: owner, amount_cents: 300)
    create(:expense_share, expense:, user: member, amount_owed_cents: 300, position: 0)
    create(:payment, group:, from_user: owner, to_user: member, reported_by_user: owner, status: :reported, amount_cents: 100)
    create(:payment, group:, from_user: member, to_user: owner, reported_by_user: member, status: :reported, amount_cents: 100)

    { group:, member: }
  end

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "senha-segura"
    click_button "Entrar"
    expect(page).to have_current_path(root_path)
  end
end
