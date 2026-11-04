require "application_system_test_case"

# Exercises Garden through real Stimulus actions, browser storage and Turbo visits.
class GardensTest < ApplicationSystemTestCase
  STORAGE_KEY = "smartWatering.garden.v1"

  setup do
    visit gardens_path
    wait_for_garden
    page.execute_script("window.localStorage.removeItem(arguments[0])", STORAGE_KEY)
    page.refresh
    wait_for_garden
  end

  test "switching zones updates selection configuration and demo readings" do
    click_button "Zone 2"

    assert_selector "h1", text: "Zone 2 - configuration"
    assert_selector ".zone-btn.active[aria-pressed='true']", text: "Zone 2", count: 1
    assert_selector ".zone-btn[aria-pressed='false']", text: "Zone 1"
    assert_select "Crops", selected: "Lettuce"
    assert_select "Watering schedule", selected: "Every day - 7:00 AM"
    assert_selector "[data-garden-target='temp']", text: "19°C"
    assert_selector "[data-garden-target='humidity']", text: "80%"
    assert_selector "[data-garden-target='brightness']", text: "620 lx"
    assert_text "Simulated sensor readings"

    active_color = page.evaluate_script("getComputedStyle(document.querySelector('.zone-btn.active')).backgroundColor")
    inactive_color = page.evaluate_script("getComputedStyle(document.querySelector('.zone-btn:not(.active)')).backgroundColor")
    assert_not_equal inactive_color, active_color

    click_button "Zone 1"
    assert_select "Crops", selected: "Tomatoes"
    assert_selector "[data-garden-target='temp']", text: "24°C"
  end

  test "new zones are numbered selected focused and have no sensor readings" do
    click_button "Add a new zone"

    assert_selector "h1", text: "Zone 3 - configuration"
    assert_selector ".zone-btn.active[aria-pressed='true']", text: "Zone 3"
    assert_equal "Zone 3", page.evaluate_script("document.activeElement.textContent")
    assert_select "Crops", selected: "Carrots"
    assert_select "Watering schedule", selected: "Every 3 days - 8:00 PM"
    assert_text "No sensors assigned"
    assert_selector ".value-box", text: "—", count: 3
    assert_no_selector ".sensor-tags"
    assert_no_text "Simulated sensor readings"

    click_button "Add a new zone"
    assert_selector "h1", text: "Zone 4 - configuration"
    assert_selector ".zone-btn", count: 4

    page.refresh
    wait_for_garden
    assert_selector ".zone-btn", count: 4
    assert_selector ".zone-btn.active", text: "Zone 4"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active", text: "Zone 5"
  end

  test "each zone retains its own configuration after switching and reloading" do
    select "Strawberries", from: "Crops"
    select "Every 3 days - 8:00 PM", from: "Watering schedule"
    click_button "Zone 2"
    assert_select "Crops", selected: "Lettuce"
    assert_select "Watering schedule", selected: "Every day - 7:00 AM"

    click_button "Add a new zone"
    select "Tomatoes", from: "Crops"
    select "Every day - 7:00 AM", from: "Watering schedule"
    page.refresh
    wait_for_garden

    assert_selector "h1", text: "Zone 3 - configuration"
    assert_select "Crops", selected: "Tomatoes"
    assert_select "Watering schedule", selected: "Every day - 7:00 AM"
    click_button "Zone 1"
    assert_select "Crops", selected: "Strawberries"
    assert_select "Watering schedule", selected: "Every 3 days - 8:00 PM"
  end

  test "Turbo visits and browser history restore zones without duplicate controls" do
    click_button "Add a new zone"
    select "Strawberries", from: "Crops"
    page.execute_script("window.gardenNavigationMarker = true; window.Turbo.visit(arguments[0])", root_path)
    assert_selector "h1", text: "Home"

    page.go_back
    wait_for_garden
    assert_selector ".zone-btn", count: 3
    assert_selector ".zone-btn.active", text: "Zone 3"
    assert_select "Crops", selected: "Strawberries"
    assert page.evaluate_script("window.gardenNavigationMarker"), "Navigation should preserve the Turbo document"

    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_selector "h1", text: "Home"
    page.execute_script("window.Turbo.visit(arguments[0])", gardens_path)
    wait_for_garden
    assert_selector ".zone-btn", count: 3
    click_button "Add a new zone"
    assert_selector ".zone-btn", count: 4
    assert_selector ".zone-btn.active", text: "Zone 4"
  end

  test "invalid saved data restores usable demo zones" do
    invalid_states = [
      "{broken JSON", "null",
      { version: 2, zones: [] }.to_json,
      { version: 1, zones: [ nil ] }.to_json,
      { version: 1, zones: [ { id: 1, crop: "Unknown", schedule: "Every day - 7:00 AM" } ] }.to_json,
      { version: 1, zones: Array.new(2) { { id: 1, crop: "Tomatoes", schedule: "Every day - 7:00 AM" } } }.to_json
    ]

    invalid_states.each do |saved_text|
      page.execute_script("window.localStorage.setItem(arguments[0], arguments[1])", STORAGE_KEY, saved_text)
      page.refresh
      wait_for_garden
      assert_selector ".zone-btn", count: 2
      assert_selector ".zone-btn.active", text: "Zone 1"
      assert_selector "[role='status']", text: "Saved zones could not be loaded"

      click_button "Add a new zone"
      assert_selector ".zone-btn.active", text: "Zone 3"
      assert_no_selector "[role='status']"
    end
  end

  test "a missing saved selection falls back to the first saved zone" do
    click_button "Zone 2"
    page.execute_script(<<~JS, STORAGE_KEY)
      const state = JSON.parse(window.localStorage.getItem(arguments[0]));
      state.selectedZoneId = 999;
      window.localStorage.setItem(arguments[0], JSON.stringify(state));
    JS
    page.refresh
    wait_for_garden

    assert_selector ".zone-btn.active", text: "Zone 1"
    assert_select "Crops", selected: "Tomatoes"
    assert_no_selector "[role='status']"
  end

  test "a storage write failure warns without interrupting zone interactions" do
    page.execute_script(<<~JS)
      Storage.prototype.setItem = function () {
        throw new DOMException("Storage is full", "QuotaExceededError");
      };
    JS
    click_button "Add a new zone"
    assert_selector ".zone-btn.active", text: "Zone 3"
    assert_selector "[role='status']", text: "Changes could not be saved"
    select "Strawberries", from: "Crops"
    click_button "Zone 1"
    click_button "Zone 3"
    assert_select "Crops", selected: "Strawberries"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active", text: "Zone 4"
  end

  test "unavailable storage still permits loading and editing the garden" do
    page.execute_script(<<~JS)
      Object.defineProperty(window, "localStorage", {
        configurable: true,
        get() { throw new DOMException("Storage is blocked", "SecurityError"); }
      });
    JS
    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_selector "h1", text: "Home"
    page.execute_script("window.Turbo.visit(arguments[0])", gardens_path)
    wait_for_garden

    assert_selector ".zone-btn", count: 2
    assert_selector "[role='status']", text: "Saved zones could not be loaded"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active", text: "Zone 3"
    assert_selector "[role='status']", text: "Changes could not be saved"
  end

  test "mobile and desktop layouts remain usable with keyboard selection" do
    long_name = "A" * 60
    fill_in "Zone name", with: long_name
    click_button "Save name"

    [ [ 390, 844 ], [ 1280, 900 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      click_button long_name
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Page should fit the viewport"
      assert_selector ".zone-add", visible: true
      find_button(long_name).send_keys(:tab)
      assert_equal "Zone 2", page.evaluate_script("document.activeElement.textContent")
      find_button("Zone 2").send_keys(:enter)
      assert_selector ".zone-btn.active", text: "Zone 2"
      assert page.evaluate_script("document.activeElement.matches(':focus-visible')"), "Keyboard focus should remain visible"
      assert_equal "solid", page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
    end
  end

  test "renaming a zone preserves its identity configuration and readings after reloading" do
    select "Strawberries", from: "Crops"
    select "Every day - 7:00 AM", from: "Watering schedule"
    fill_in "Zone name", with: "  Greenhouse  "
    click_button "Save name"

    assert_selector "h1", text: "Greenhouse - configuration"
    assert_selector ".zone-btn.active[data-zone-id='1']", text: "Greenhouse"
    assert_field "Zone name", with: "Greenhouse"
    assert_selector "[data-garden-target='temp']", text: "24°C"
    click_button "Zone 2"
    assert_select "Crops", selected: "Lettuce"
    click_button "Greenhouse"
    page.refresh
    wait_for_garden

    assert_selector "h1", text: "Greenhouse - configuration"
    assert_select "Crops", selected: "Strawberries"
    assert_select "Watering schedule", selected: "Every day - 7:00 AM"
    assert_field "Zone name", with: "Greenhouse"
    assert_selector ".zone-btn", count: 2
  end

  test "blank and duplicate names are rejected without changing the saved zone" do
    fill_in "Zone name", with: "   "
    click_button "Save name"
    assert_selector "[role='alert']", text: "Enter a zone name"
    assert_selector "#zone-name[aria-invalid='true']"
    assert_selector "h1", text: "Zone 1 - configuration"

    fill_in "Zone name", with: " zone 2 "
    assert_no_selector "[role='alert']"
    click_button "Save name"
    assert_selector "[role='alert']", text: "Another zone already uses this name"
    click_button "Zone 2"
    assert_no_selector "[role='alert']"
    assert_field "Zone name", with: "Zone 2"
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn", text: "Zone 1"
    assert_selector ".zone-btn", text: "Zone 2"
  end

  test "deleting a zone is immediate without a dialog and preserves the remaining zone settings" do
    select "Strawberries", from: "Crops"
    click_button "Zone 2"
    page.execute_script(<<~JS)
      window.confirm = window.alert = window.prompt = function () {
        throw new Error("Deleting a zone must not open a dialog");
      };
    JS
    click_button "Delete zone"
    assert_no_button "Zone 2"
    assert_selector ".zone-btn.active", text: "Zone 1"
    assert_equal "Zone 1", page.evaluate_script("document.activeElement.textContent")
    assert_select "Crops", selected: "Strawberries"
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn", count: 1
    assert_no_button "Zone 2"
    assert_select "Crops", selected: "Strawberries"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 2"
  end

  test "deleting every zone keeps the garden empty until a new zone is created" do
    2.times do
      click_button "Delete zone"
    end
    assert_no_selector ".zone-btn"
    assert_text "No zones yet"
    assert_no_field "Zone name"
    assert_no_select "Crops"
    assert_no_selector ".garden-right-col"
    assert_no_button "Start"
    assert_no_button "Delete zone"
    assert_equal "Add a new zone", page.evaluate_script("document.activeElement.getAttribute('aria-label')")

    page.refresh
    wait_for_garden
    assert_no_selector ".zone-btn"
    assert_text "No zones yet"
    assert_no_selector "[role='status']"
    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_selector "h1", text: "Home"
    page.go_back
    wait_for_garden
    assert_no_selector ".zone-btn"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 1"
    assert_field "Zone name", with: "Zone 1"
    assert_text "No sensors assigned"
    assert_selector ".value-box", text: "—", count: 3
  end

  test "new zone identifiers survive deletion and avoid names already in use" do
    fill_in "Zone name", with: "Zone 3"
    click_button "Save name"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 1"
    click_button "Delete zone"
    page.refresh
    wait_for_garden
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='4']", text: "Zone 1"
    assert_selector ".zone-btn", count: 3
    assert_selector ".zone-btn", text: "Zone 3", count: 1
  end

  test "creation fills numbering gaps and orders zone ten after zone nine" do
    9.times { click_button "Add a new zone" }
    assert_equal (1..11).map { |number| "Zone #{number}" }, all(".zone-btn").map(&:text)
    click_button "Zone 4", exact: true
    click_button "Delete zone"
    page.refresh
    wait_for_garden
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='12']", text: "Zone 4"
    assert_equal (1..11).map { |number| "Zone #{number}" }, all(".zone-btn").map(&:text)
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn.active[data-zone-id='12']", text: "Zone 4"
    assert_text "No sensors assigned"
  end

  test "old automatic numbering is repaired without changing custom names configuration or identity" do
    old_state = {
      version: 1, selectedZoneId: 19, nextZoneId: 20,
      zones: [ 1, 2, 3, 19 ].map do |id|
        { id: id, name: "Zone #{id}", crop: "Carrots", schedule: "Every day - 7:00 AM", sensorIds: [] }
      end
    }
    old_state[:zones] << { id: 7, name: "Greenhouse", crop: "Strawberries", schedule: "Every day - 7:00 AM", sensorIds: [] }
    page.execute_script("window.localStorage.setItem(arguments[0], arguments[1])", STORAGE_KEY, old_state.to_json)
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn.active[data-zone-id='19']", text: "Zone 4"
    assert_select "Crops", selected: "Carrots"
    assert_select "Watering schedule", selected: "Every day - 7:00 AM"
    assert_button "Greenhouse"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='20']", text: "Zone 5"
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn.active[data-zone-id='20']", text: "Zone 5"
    click_button "Greenhouse"
    assert_select "Crops", selected: "Strawberries"
  end

  test "zones saved before name editing remain usable" do
    legacy_state = {
      version: 1, selectedZoneId: 2,
      zones: [
        { id: 1, crop: "Tomatoes", schedule: "Every 2 days - 6:00 AM" },
        { id: 2, crop: "Strawberries", schedule: "Every 3 days - 8:00 PM" }
      ]
    }
    page.execute_script("window.localStorage.setItem(arguments[0], arguments[1])", STORAGE_KEY, legacy_state.to_json)
    page.refresh
    wait_for_garden

    assert_no_selector "[role='status']"
    assert_selector ".zone-btn.active", text: "Zone 2"
    assert_select "Crops", selected: "Strawberries"
    assert_field "Zone name", with: "Zone 2"
    fill_in "Zone name", with: "Lettuce bed"
    click_button "Save name"
    page.refresh
    wait_for_garden
    assert_selector "h1", text: "Lettuce bed - configuration"
    click_button "Add a new zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 2"
    assert_selector ".value-box", text: "—", count: 3
  end

  test "the garden is centered in the actual viewport and stacks on mobile" do
    [ [ 320, 1 ], [ 390, 1 ], [ 768, 1 ], [ 1280, 2 ], [ 1600, 2 ] ].each do |width, columns|
      # An iframe gives Firefox an exact viewport even below its minimum window width.
      page.execute_script(<<~JS, gardens_path, width)
        document.getElementById("responsive-preview")?.remove();
        const frame = document.createElement("iframe");
        frame.id = "responsive-preview";
        frame.src = arguments[0];
        frame.style.cssText = `width:${arguments[1]}px;height:2400px;border:0;display:block`;
        document.body.append(frame);
      JS
      within_frame "responsive-preview" do
        wait_for_garden
        metrics = page.evaluate_script(<<~JS)
          (() => {
          const grid = document.querySelector(".garden-page");
          const bounds = grid.getBoundingClientRect();
          const titleStyle = getComputedStyle(document.querySelector("h1"));
          return {
            width: window.innerWidth,
            centered: Math.abs(bounds.x + bounds.width / 2 - document.documentElement.clientWidth / 2) < 1,
            fits: document.documentElement.scrollWidth <= window.innerWidth,
            columns: getComputedStyle(grid).gridTemplateColumns.split(" ").length,
            titleWeight: titleStyle.fontWeight
          };
          })()
        JS
        assert_equal width, metrics["width"]
        assert metrics["centered"], "Garden should be centered at #{width}px"
        assert metrics["fits"], "Garden should fit at #{width}px"
        assert_equal columns, metrics["columns"]
        assert_equal "900", metrics["titleWeight"]
      end
    end
  end

  test "demo sensors show health and readings independently for each zone and survive reloading" do
    click_button "Add a new zone"
    assert_button "Assign sensor", disabled: true
    assert_select "Available sensor", options: [ "Select a sensor", "Temperature · T-03", "Humidity · H-03", "Brightness · B-03" ]
    select "Temperature · T-03", from: "Available sensor"
    click_button "Assign sensor"
    assert_selector ".sensor-item", text: "Temperature · T-03"
    assert_selector ".sensor-health", text: "Healthy"
    assert_selector "[data-garden-target='temp']", text: "22°C"
    assert_select "Available sensor", options: [ "Select a sensor", "Humidity · H-03", "Brightness · B-03" ]

    select "Humidity · H-03", from: "Available sensor"
    click_button "Assign sensor"
    select "Brightness · B-03", from: "Available sensor"
    click_button "Assign sensor"
    assert_selector ".sensor-health", text: "Low battery"
    assert_selector ".sensor-health", text: "Offline"
    assert_selector "[data-garden-target='humidity']", text: "58%"
    assert_selector "[data-garden-target='brightness']", text: "—"
    assert_selector "#sensor-select:disabled"
    assert_text "Demo devices · simulated health and readings"

    page.refresh
    wait_for_garden
    assert_selector ".sensor-item", count: 3
    assert_selector "[data-garden-target='temp']", text: "22°C"
    click_button "Zone 1"
    assert_selector ".sensor-item", text: "Temperature · T-01"
    assert_no_selector ".sensor-item", text: "Temperature · T-03"
    assert_selector "[data-garden-target='temp']", text: "24°C"
  end

  test "removing and deleting releases sensors for assignment to other zones" do
    find("button[aria-label='Remove Temperature · T-01']").click
    assert_selector "[data-garden-target='temp']", text: "—"
    assert_selector ".sensor-item", count: 2
    page.refresh
    wait_for_garden
    assert_selector ".sensor-item", count: 2
    click_button "Add a new zone"
    select "Temperature · T-01", from: "Available sensor"
    click_button "Assign sensor"
    assert_selector "[data-garden-target='temp']", text: "24°C"
    assert_selector ".sensor-item", count: 1
    click_button "Zone 1"
    assert_select "Available sensor", options: [ "Select a sensor", "Temperature · T-03" ]
    click_button "Zone 3"
    click_button "Delete zone"
    click_button "Zone 1"
    select "Temperature · T-01", from: "Available sensor"
    click_button "Assign sensor"
    assert_selector ".sensor-item", count: 3
    assert_selector "[data-garden-target='temp']", text: "24°C"
  end

  private

  # Waits for the controller to finish connecting instead of clicking static fallback HTML.
  def wait_for_garden
    page.document.synchronize do
      connected = page.evaluate_script(<<~JS)
        Boolean(window.Stimulus?.getControllerForElementAndIdentifier(
          document.querySelector('[data-controller="garden"]'), "garden"
        ))
      JS
      raise Capybara::ElementNotFound, "Garden controller has not connected" unless connected
    end
  end
end
