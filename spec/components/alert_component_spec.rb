require "rails_helper"
require "view_component/test_helpers"

RSpec.describe AlertComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renderiza uma mensagem de erro identificável" do
    render_inline(described_class.new(message: "Não foi possível concluir a ação."))

    expect(page).to have_css("[role='alert']", text: "Não foi possível concluir a ação.")
  end

  it "anuncia sucesso como status e preserva alerta para avisos e erros" do
    render_inline(described_class.new(message: "Grupo salvo.", variant: :success))

    expect(page).to have_css("[role='status'].ui-alert--success", text: "Grupo salvo.")

    render_inline(described_class.new(message: "Revise os dados.", variant: :warning))

    expect(page).to have_css("[role='alert'].ui-alert--warning", text: "Revise os dados.")
  end
end
