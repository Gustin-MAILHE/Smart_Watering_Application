require "test_helper"

# Runs browser interactions with the JavaScript stack used by the application.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  firefox_binary = ENV["FIREFOX_BIN"].presence || ENV["SE_FIREFOX_PATH"].presence
  snap_firefox = "/snap/firefox/current/usr/lib/firefox"

  # Ubuntu's /usr/bin/firefox may be a Snap launcher, which GeckoDriver cannot use as a binary.
  if firefox_binary.nil? && File.executable?("#{snap_firefox}/firefox")
    firefox_binary = "#{snap_firefox}/firefox"
    if ENV["SE_GECKODRIVER"].blank? && File.executable?("#{snap_firefox}/geckodriver")
      ENV["SE_GECKODRIVER"] = "#{snap_firefox}/geckodriver"
    end
  end

  driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ] do |options|
    options.binary = firefox_binary if firefox_binary.present?
  end

  # Exercise existing zone features through the same step buttons used by visitors.
  def garden_step(name)
    button = find(".garden-step-button", text: name)
    button.click unless button["aria-current"] == "step"
    assert_selector ".garden-step-button[aria-current=step]", text: name
  end
end
