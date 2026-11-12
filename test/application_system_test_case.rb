require "test_helper"

# Runs browser interactions with the JavaScript stack used by the application.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ] do |options|
    options.binary = ENV["FIREFOX_BIN"] if ENV["FIREFOX_BIN"].present?
  end

  # Exercise existing zone features through the same step buttons used by visitors.
  def garden_step(name)
    button = find(".garden-step-button", text: name)
    button.click unless button["aria-current"] == "step"
    assert_selector ".garden-step-button[aria-current=step]", text: name
  end
end
