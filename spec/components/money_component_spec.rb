require "rails_helper"
require "view_component/test_helpers"

RSpec.describe MoneyComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renderiza valor monetário acessível" do
    render_inline(described_class.new(cents: 250, currency_code: "BRL"))

    expect(page).to have_css("data[role='money']", text: "R$ 2,50")
  end
end
