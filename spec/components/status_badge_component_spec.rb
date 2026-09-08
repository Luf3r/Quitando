require "rails_helper"
require "view_component/test_helpers"

RSpec.describe StatusBadgeComponent, type: :component do
  include ViewComponent::TestHelpers

  it "preserva o status canônico e permite um rótulo contextual" do
    render_inline(described_class.new(status: "reported", label: "Aguardando Ana"))

    expect(page).to have_css("span.ui-badge[data-status='reported'][data-tone='attention']", text: "Aguardando Ana")
  end

  it "distingue estados positivos, neutros e negativos sem depender somente do texto" do
    {
      "settled" => "positive",
      "archived" => "neutral",
      "cancelled" => "negative"
    }.each do |status, tone|
      render_inline(described_class.new(status:))

      expect(page).to have_css("span.ui-badge--#{tone}[data-status='#{status}'][data-tone='#{tone}']")
    end
  end
end
