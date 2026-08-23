require "selenium-webdriver"

Capybara.register_driver(:chrome_headless) do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV.fetch("CHROME_BIN", "/usr/bin/chromium")
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
end

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 8
