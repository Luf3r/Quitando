require "rails_helper"
require "view_component/test_helpers"

RSpec.describe "Componentes do design system", type: :component do
  include ViewComponent::TestHelpers

  it "renderiza botão primário como link sem perder o nome acessível" do
    render_inline(ButtonComponent.new(label: "Criar grupo", href: "/groups/new"))

    expect(page).to have_link("Criar grupo", href: "/groups/new", class: /ui-button--primary/)
  end

  it "torna a ação secundária visualmente reconhecível e permite escolher o tamanho" do
    render_inline(ButtonComponent.new(label: "Histórico completo", href: "/groups/1/history", variant: :secondary, size: :compact))

    expect(page).to have_link(
      "Histórico completo",
      href: "/groups/1/history",
      class: /ui-button--secondary.*ui-button--compact/
    )
    expect(page).not_to have_css(".ui-button--primary", text: "Histórico completo")
  end

  it "gera um formulário para um destino mutável e torna um link desabilitado inerte" do
    render_inline(ButtonComponent.new(label: "Arquivar", href: "/groups/1/archive", method: :post))

    expect(page).to have_css("form[action='/groups/1/archive'][method='post'] button", text: "Arquivar")

    render_inline(ButtonComponent.new(label: "Indisponível", href: "/groups/1", disabled: true))

    expect(page).to have_css("span.ui-button[aria-disabled='true']", text: "Indisponível")
    expect(page).not_to have_link("Indisponível")
    expect { ButtonComponent.new(label: "Inválido", method: :post) }.to raise_error(ArgumentError, "method requires href")
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

  it "renderiza select com a opção submetida" do
    render_inline(FieldComponent.new(label: "Pago por", name: "expense[paid_by_user_id]", type: :select, value: "bia", choices: [ [ "Ana", "ana" ], [ "Bia", "bia" ] ]))

    expect(page).to have_select("Pago por", selected: "Bia")
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

  it "inclui um menu móvel nativo com os mesmos destinos autenticados" do
    user = build_stubbed(:user, email: "ana@example.com")

    render_inline(NavigationComponent.new(user:, pending_invitation_count: 2))

    menu = page.find("details.site-navigation__mobile")
    expect(menu).to have_css("summary", text: "Menu")
    expect(menu).to have_link("Grupos", href: "/groups", visible: :all)
    expect(menu).to have_link("Convites 2", href: "/invitations", visible: :all)
    expect(menu).to have_link("Conta", href: "/account", visible: :all)
    expect(menu).to have_select("Tema", options: %w[Sistema Claro Escuro], visible: :all)
    expect(menu).to have_button("Sair", visible: :all)
  end
end
