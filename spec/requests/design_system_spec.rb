require "rails_helper"

RSpec.describe "Fundação visual" do
  it "aplica a preferência de tema antes do stylesheet e mantém um único main" do
    get root_path

    document = Nokogiri::HTML(response.body)
    theme_script = document.at_css("script[data-theme-bootstrap]")
    stylesheet = document.at_css("link[rel='stylesheet']")

    expect(theme_script).to be_present
    expect(stylesheet).to be_present
    head_children = document.at_css("head").element_children
    expect(head_children.index(theme_script)).to be < head_children.index(stylesheet)
    expect(document.css("main").size).to eq(1)
    expect(document.at_css("html")["data-theme"]).to eq("system")
  end
end
