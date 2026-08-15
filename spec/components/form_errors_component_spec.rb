require "rails_helper"
require "view_component/test_helpers"

RSpec.describe FormErrorsComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renderiza os erros em uma região identificável" do
    render_inline(described_class.new(messages: [ "Nome não pode ficar em branco" ]))

    expect(page).to have_css("[role='alert']", text: "Nome não pode ficar em branco")
  end
end
