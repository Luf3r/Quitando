require "rails_helper"
require "view_component/test_helpers"

RSpec.describe StatusBadgeComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renderiza o estado como texto, além da cor" do
    render_inline(described_class.new(status: "settled"))

    expect(page).to have_css("span", text: "Quitado")
  end
end
