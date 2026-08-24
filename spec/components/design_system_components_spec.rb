require "rails_helper"
require "view_component/test_helpers"

RSpec.describe "Componentes do design system", type: :component do
  include ViewComponent::TestHelpers

  it "renderiza botão primário como link sem perder o nome acessível" do
    render_inline(ButtonComponent.new(label: "Criar grupo", href: "/groups/new"))

    expect(page).to have_link("Criar grupo", href: "/groups/new", class: /ui-button--primary/)
  end

  it "renderiza campo com label, ajuda e erro associados" do
    render_inline(
      FieldComponent.new(
        label: "Nome do grupo",
        name: "group[name]",
        value: "Viagem",
        hint: "Use um nome reconhecível.",
        errors: [ "Nome não pode ficar em branco" ]
      )
    )

    expect(page).to have_field("Nome do grupo", with: "Viagem")
    expect(page).to have_css("input[aria-invalid='true']")
    expect(page).to have_css("[id$='_hint']", text: "Use um nome reconhecível.")
    expect(page).to have_css("[id$='_error']", text: "Nome não pode ficar em branco")
  end

  it "renderiza empty state e cabeçalho de página com ação clara" do
    render_inline(
      EmptyStateComponent.new(
        title: "Nenhum grupo ainda",
        body: "Crie um grupo para começar.",
        action_label: "Criar grupo",
        action_path: "/groups"
      )
    )

    expect(page).to have_css("h2", text: "Nenhum grupo ainda")
    expect(page).to have_link("Criar grupo", href: "/groups")

    render_inline(PageHeaderComponent.new(title: "Seus grupos", description: "Acompanhe o que falta encerrar."))

    expect(page).to have_css("h1", text: "Seus grupos")
    expect(page).to have_text("Acompanhe o que falta encerrar.")
  end

  it "renderiza navegação autenticada com contagem e seletor de tema" do
    user = build_stubbed(:user, email: "ana@example.com")

    render_inline(NavigationComponent.new(user:, pending_invitation_count: 2))

    expect(page).to have_link("Grupos", href: "/groups")
    expect(page).to have_link("Convites 2", href: "/invitations")
    expect(page).to have_link("Conta", href: "/account")
    expect(page).to have_select("Tema", options: %w[Sistema Claro Escuro])
    expect(page).to have_button("Sair")
  end
end
