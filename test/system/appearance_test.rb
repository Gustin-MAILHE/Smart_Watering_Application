require "application_system_test_case"

# Covers shared layout behavior across Jardin, Accueil and exact mobile viewports.
class AppearanceTest < ApplicationSystemTestCase
  setup do
    visit gardens_path
    wait_for_appearance
    page.execute_script("localStorage.removeItem('smartWatering.theme')")
    page.refresh
    wait_for_appearance
  end

  test "theme survives reloads and Turbo visits and supports keyboard activation" do
    assert_selector "html[data-theme='dark']"
    assert_selector "[data-appearance-target='moon']", visible: true
    assert_no_selector "[data-appearance-target='sun']", visible: true
    find(".theme-toggle").click
    assert_selector "html[data-theme='light']"
    assert_selector "[data-appearance-target='sun']", visible: true
    assert_no_selector "[data-appearance-target='moon']", visible: true
    assert_selector ".theme-toggle[aria-label='Passer en mode nuit']"
    page.refresh
    wait_for_appearance
    assert_selector "html[data-theme='light']"
    assert_selector "[data-appearance-target='sun']", visible: true
    assert_no_selector "[data-appearance-target='moon']", visible: true
    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_selector ".home-page"
    wait_for_appearance
    assert_selector "html[data-theme='light']"
    find(".theme-toggle").send_keys(:enter)
    assert_selector "html[data-theme='dark']"
    assert_selector "[data-appearance-target='moon']", visible: true
    assert_no_selector "[data-appearance-target='sun']", visible: true
    assert_selector ".theme-toggle[aria-label='Passer en mode jour']"
  end

  test "sticky header keeps a full height drawer and back to top follows scrolling" do
    assert_no_selector ".back-to-top"
    page.execute_script("window.scrollTo({top: 600, behavior: 'instant'})")
    assert_selector ".back-to-top"
    assert_in_delta 0, page.evaluate_script("document.querySelector('.site-header').getBoundingClientRect().top"), 1
    find("#open-menu").click
    assert_selector "sl-drawer[open]"
    height = page.evaluate_script("document.querySelector('sl-drawer').shadowRoot.querySelector('[part~=panel]').getBoundingClientRect().height")
    assert_in_delta page.evaluate_script("window.innerHeight"), height, 2
    page.execute_script("document.querySelector('sl-drawer').hide()")
    assert_no_selector "sl-drawer[open]"
    find(".back-to-top").click
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "Page has not reached the top" unless page.evaluate_script("window.scrollY < 1")
    end
    assert_no_selector ".back-to-top"
    assert_equal "site-header__title", page.evaluate_script("document.activeElement.className")
  end

  test "theme remains usable when storage writes are blocked" do
    page.execute_script("Storage.prototype.setItem = function () { throw new DOMException('Full', 'QuotaExceededError') }")
    find(".theme-toggle").click
    assert_selector "html[data-theme='light']"
    find(".theme-toggle").click
    assert_selector "html[data-theme='dark']"
  end

  test "shared controls and footer fit exact mobile and desktop widths" do
    [ 320, 390, 768, 1280 ].each do |width|
      page.execute_script(<<~JS, gardens_path, width)
        document.getElementById('layout-preview')?.remove();
        const frame = document.createElement('iframe');
        frame.id = 'layout-preview';
        frame.src = arguments[0];
        frame.style.cssText = `width:${arguments[1]}px;height:1000px;border:0;display:block;position:fixed;top:88px;left:0;z-index:200`;
        document.body.append(frame);
      JS
      within_frame "layout-preview" do
        wait_for_appearance
        page.execute_script("document.documentElement.dataset.theme = 'dark'")
        assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "Layout should fit at #{width}px"
        assert_selector ".theme-toggle", count: 1
        assert_selector ".site-footer .footer-links a", count: 3
        find(".theme-toggle").click
        assert_selector "html[data-theme='light']", visible: :all
        find(".theme-toggle").click
        assert_selector "html[data-theme='dark']", visible: :all
      end
    end
  end

  private

  # Waits until the shared controller can handle user interactions.
  def wait_for_appearance
    page.document.synchronize do
      connected = page.evaluate_script("Boolean(window.Stimulus?.getControllerForElementAndIdentifier(document.body, 'appearance'))")
      raise Capybara::ElementNotFound, "Appearance controller has not connected" unless connected
    end
  end
end
