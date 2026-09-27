require "rails_helper"

RSpec.describe "Landing visual", type: :system do
  before { driven_by(:chrome_headless) }

  it "mantém o título do hero em até duas linhas no desktop" do
    page.driver.browser.manage.window.resize_to(1440, 1000)
    visit root_path

    measurements = page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector("#landing-title")
        const style = getComputedStyle(title)
        const rect = title.getBoundingClientRect()
        return { height: rect.height, lineHeight: Number(style.lineHeight.replace("px", "")) }
      })()
    JS

    expect((measurements.fetch("height") / measurements.fetch("lineHeight")).round).to be <= 2
  end
end
