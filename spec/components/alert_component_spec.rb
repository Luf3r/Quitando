require "rails_helper"
require "view_component/test_helpers"

RSpec.describe AlertComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renderiza uma mensagem de erro identificável" do
    render_inline(described_class.new(message: "Não foi possível concluir a ação."))

    expect(page).to have_css("[role='alert']", text: "Não foi possível concluir a ação.")
  end
end
