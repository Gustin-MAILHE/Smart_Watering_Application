require "test_helper"

# Runs browser interactions with the JavaScript stack used by the application.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ] do |options|
    options.binary = ENV["FIREFOX_BIN"] if ENV["FIREFOX_BIN"].present?
  end
end
