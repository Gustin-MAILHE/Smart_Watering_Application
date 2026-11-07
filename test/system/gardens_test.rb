require "application_system_test_case"

# Exercises Jardin through real Stimulus actions, browser storage and Turbo visits.
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
    assert_select "Cultures", selected: "Laitues"
    assert_select "Programme d’arrosage", selected: "Tous les jours à 07 h 00"
    assert_selector "[data-garden-target='temp']", text: "19°C"
    assert_selector "[data-garden-target='humidity']", text: "80%"
    assert_selector "[data-garden-target='brightness']", text: "620 lx"
    assert_text "Mesures simulées"

    active_color = page.evaluate_script("getComputedStyle(document.querySelector('.zone-btn.active')).backgroundColor")
    inactive_color = page.evaluate_script("getComputedStyle(document.querySelector('.zone-btn:not(.active)')).backgroundColor")
    assert_not_equal inactive_color, active_color

    click_button "Zone 1"
    assert_select "Cultures", selected: "Tomates"
    assert_selector "[data-garden-target='temp']", text: "24°C"
  end

  test "new zones are numbered selected focused and have no sensor readings" do
    click_button "Ajouter une zone"

    assert_selector "h1", text: "Zone 3 - configuration"
    assert_selector ".zone-btn.active[aria-pressed='true']", text: "Zone 3"
    assert_equal "Zone 3", page.evaluate_script("document.activeElement.textContent")
    assert_select "Cultures", selected: "Carottes"
    assert_select "Programme d’arrosage", selected: "Tous les 3 jours à 20 h 00"
    assert_text "Aucun capteur attribué"
    assert_selector ".value-box", text: "—", count: 3
    assert_no_selector ".sensor-tags"
    assert_no_text "Mesures simulées"

    click_button "Ajouter une zone"
    assert_selector "h1", text: "Zone 4 - configuration"
    assert_selector ".zone-btn", count: 4

    page.refresh
    wait_for_garden
    assert_selector ".zone-btn", count: 4
    assert_selector ".zone-btn.active", text: "Zone 4"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 5"
  end

  test "each zone retains its own configuration after switching and reloading" do
    select "Fraises", from: "Cultures"
    select "Tous les 3 jours à 20 h 00", from: "Programme d’arrosage"
    click_button "Zone 2"
    assert_select "Cultures", selected: "Laitues"
    assert_select "Programme d’arrosage", selected: "Tous les jours à 07 h 00"

    click_button "Ajouter une zone"
    select "Tomates", from: "Cultures"
    select "Tous les jours à 07 h 00", from: "Programme d’arrosage"
    page.refresh
    wait_for_garden

    assert_selector "h1", text: "Zone 3 - configuration"
    assert_select "Cultures", selected: "Tomates"
    assert_select "Programme d’arrosage", selected: "Tous les jours à 07 h 00"
    click_button "Zone 1"
    assert_select "Cultures", selected: "Fraises"
    assert_select "Programme d’arrosage", selected: "Tous les 3 jours à 20 h 00"
  end

  test "Turbo visits and browser history restore zones without duplicate controls" do
    click_button "Ajouter une zone"
    select "Fraises", from: "Cultures"
    page.execute_script("window.gardenNavigationMarker = true; window.Turbo.visit(arguments[0])", root_path)
    assert_current_path root_path
    assert_selector ".home-page"

    page.go_back
    wait_for_garden
    assert_selector ".zone-btn", count: 3
    assert_selector ".zone-btn.active", text: "Zone 3"
    assert_select "Cultures", selected: "Fraises"
    assert page.evaluate_script("window.gardenNavigationMarker"), "Navigation should preserve the Turbo document"

    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_current_path root_path
    assert_selector ".home-page"
    page.execute_script("window.Turbo.visit(arguments[0])", gardens_path)
    wait_for_garden
    assert_selector ".zone-btn", count: 3
    click_button "Ajouter une zone"
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
      assert_selector "[role='status']", text: "Impossible de charger les zones enregistrées"

      click_button "Ajouter une zone"
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
    assert_select "Cultures", selected: "Tomates"
    assert_no_selector "[role='status']"
  end

  test "a storage write failure warns without interrupting zone interactions" do
    page.execute_script(<<~JS)
      Storage.prototype.setItem = function () {
        throw new DOMException("Storage is full", "QuotaExceededError");
      };
    JS
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 3"
    assert_selector "[role='status']", text: "Impossible d’enregistrer les modifications"
    select "Fraises", from: "Cultures"
    click_button "Zone 1"
    click_button "Zone 3"
    assert_select "Cultures", selected: "Fraises"
    click_button "Ajouter une zone"
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
    assert_current_path root_path
    assert_selector ".home-page"
    page.execute_script("window.Turbo.visit(arguments[0])", gardens_path)
    wait_for_garden

    assert_selector ".zone-btn", count: 2
    assert_selector "[role='status']", text: "Impossible de charger les zones enregistrées"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 3"
    assert_selector "[role='status']", text: "Impossible d’enregistrer les modifications"
  end

  test "mobile and desktop layouts remain usable with keyboard selection" do
    long_name = "A" * 60
    fill_in "Nom de la zone", with: long_name
    click_button "Enregistrer le nom"

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
    select "Fraises", from: "Cultures"
    select "Tous les jours à 07 h 00", from: "Programme d’arrosage"
    fill_in "Nom de la zone", with: "  Greenhouse  "
    click_button "Enregistrer le nom"

    assert_selector "h1", text: "Greenhouse - configuration"
    assert_selector ".zone-btn.active[data-zone-id='1']", text: "Greenhouse"
    assert_field "Nom de la zone", with: "Greenhouse"
    assert_selector "[data-garden-target='temp']", text: "24°C"
    click_button "Zone 2"
    assert_select "Cultures", selected: "Laitues"
    click_button "Greenhouse"
    page.refresh
    wait_for_garden

    assert_selector "h1", text: "Greenhouse - configuration"
    assert_select "Cultures", selected: "Fraises"
    assert_select "Programme d’arrosage", selected: "Tous les jours à 07 h 00"
    assert_field "Nom de la zone", with: "Greenhouse"
    assert_selector ".zone-btn", count: 2
  end

  test "blank and duplicate names are rejected without changing the saved zone" do
    fill_in "Nom de la zone", with: "   "
    click_button "Enregistrer le nom"
    assert_selector "[role='alert']", text: "Saisissez un nom de zone"
    assert_selector "#zone-name[aria-invalid='true']"
    assert_selector "h1", text: "Zone 1 - configuration"

    fill_in "Nom de la zone", with: " zone 2 "
    assert_no_selector "[role='alert']"
    click_button "Enregistrer le nom"
    assert_selector "[role='alert']", text: "Une autre zone utilise déjà ce nom"
    click_button "Zone 2"
    assert_no_selector "[role='alert']"
    assert_field "Nom de la zone", with: "Zone 2"
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn", text: "Zone 1"
    assert_selector ".zone-btn", text: "Zone 2"
  end

  test "deleting a zone is immediate without a dialog and preserves the remaining zone settings" do
    select "Fraises", from: "Cultures"
    click_button "Zone 2"
    page.execute_script(<<~JS)
      window.confirm = window.alert = window.prompt = function () {
        throw new Error("Deleting a zone must not open a dialog");
      };
    JS
    click_button "Supprimer la zone"
    assert_no_button "Zone 2"
    assert_selector ".zone-btn.active", text: "Zone 1"
    assert_equal "Zone 1", page.evaluate_script("document.activeElement.textContent")
    assert_select "Cultures", selected: "Fraises"
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn", count: 1
    assert_no_button "Zone 2"
    assert_select "Cultures", selected: "Fraises"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 2"
  end

  test "deleting every zone keeps the garden empty until a new zone is created" do
    2.times do
      click_button "Supprimer la zone"
    end
    assert_no_selector ".zone-btn"
    assert_text "Aucune zone pour le moment"
    assert_no_field "Nom de la zone"
    assert_no_select "Cultures"
    assert_no_selector ".garden-right-col"
    assert_no_button "Démarrer"
    assert_no_button "Supprimer la zone"
    assert_equal "Ajouter une zone", page.evaluate_script("document.activeElement.getAttribute('aria-label')")

    page.refresh
    wait_for_garden
    assert_no_selector ".zone-btn"
    assert_text "Aucune zone pour le moment"
    assert_no_selector "[role='status']"
    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_current_path root_path
    assert_selector ".home-page"
    page.go_back
    wait_for_garden
    assert_no_selector ".zone-btn"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 1"
    assert_field "Nom de la zone", with: "Zone 1"
    assert_text "Aucun capteur attribué"
    assert_selector ".value-box", text: "—", count: 3
  end

  test "new zone identifiers survive deletion and avoid names already in use" do
    fill_in "Nom de la zone", with: "Zone 3"
    click_button "Enregistrer le nom"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active[data-zone-id='3']", text: "Zone 1"
    click_button "Supprimer la zone"
    page.refresh
    wait_for_garden
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active[data-zone-id='4']", text: "Zone 1"
    assert_selector ".zone-btn", count: 3
    assert_selector ".zone-btn", text: "Zone 3", count: 1
  end

  test "creation fills numbering gaps and orders zone ten after zone nine" do
    9.times { click_button "Ajouter une zone" }
    assert_equal (1..11).map { |number| "Zone #{number}" }, all(".zone-btn").map(&:text)
    click_button "Zone 4", exact: true
    click_button "Supprimer la zone"
    page.refresh
    wait_for_garden
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active[data-zone-id='12']", text: "Zone 4"
    assert_equal (1..11).map { |number| "Zone #{number}" }, all(".zone-btn").map(&:text)
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn.active[data-zone-id='12']", text: "Zone 4"
    assert_text "Aucun capteur attribué"
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
    assert_select "Cultures", selected: "Carottes"
    assert_select "Programme d’arrosage", selected: "Tous les jours à 07 h 00"
    assert_button "Greenhouse"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active[data-zone-id='20']", text: "Zone 5"
    page.refresh
    wait_for_garden
    assert_selector ".zone-btn.active[data-zone-id='20']", text: "Zone 5"
    click_button "Greenhouse"
    assert_select "Cultures", selected: "Fraises"
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
    assert_select "Cultures", selected: "Fraises"
    assert_field "Nom de la zone", with: "Zone 2"
    fill_in "Nom de la zone", with: "Laitues bed"
    click_button "Enregistrer le nom"
    page.refresh
    wait_for_garden
    assert_selector "h1", text: "Laitues bed - configuration"
    click_button "Ajouter une zone"
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
        assert metrics["centered"], "Jardin should be centered at #{width}px"
        assert metrics["fits"], "Jardin should fit at #{width}px"
        assert_equal columns, metrics["columns"]
        assert_equal "900", metrics["titleWeight"]
      end
    end
  end

  test "demo sensors show health and readings independently for each zone and survive reloading" do
    click_button "Ajouter une zone"
    assert_button "Attribuer le capteur", disabled: true
    assert_select "Capteur disponible", options: [ "Choisir un capteur", "Température · T-03", "Humidité · H-03", "Luminosité · B-03" ]
    select "Température · T-03", from: "Capteur disponible"
    click_button "Attribuer le capteur"
    assert_selector ".sensor-item", text: "Température · T-03"
    assert_selector ".sensor-health", text: "En bon état"
    assert_selector "[data-garden-target='temp']", text: "22°C"
    assert_select "Capteur disponible", options: [ "Choisir un capteur", "Humidité · H-03", "Luminosité · B-03" ]

    select "Humidité · H-03", from: "Capteur disponible"
    click_button "Attribuer le capteur"
    select "Luminosité · B-03", from: "Capteur disponible"
    click_button "Attribuer le capteur"
    assert_selector ".sensor-health", text: "Batterie faible"
    assert_selector ".sensor-health", text: "Hors ligne"
    assert_selector "[data-garden-target='humidity']", text: "58%"
    assert_selector "[data-garden-target='brightness']", text: "—"
    assert_selector "#sensor-select:disabled"
    assert_text "Capteurs de démonstration · état et mesures simulés"

    page.refresh
    wait_for_garden
    assert_selector ".sensor-item", count: 3
    assert_selector "[data-garden-target='temp']", text: "22°C"
    click_button "Zone 1"
    assert_selector ".sensor-item", text: "Température · T-01"
    assert_no_selector ".sensor-item", text: "Température · T-03"
    assert_selector "[data-garden-target='temp']", text: "24°C"
  end

  test "removing and deleting releases sensors for assignment to other zones" do
    find("button[aria-label='Retirer Température · T-01']").click
    assert_selector "[data-garden-target='temp']", text: "—"
    assert_selector ".sensor-item", count: 2
    page.refresh
    wait_for_garden
    assert_selector ".sensor-item", count: 2
    click_button "Ajouter une zone"
    select "Température · T-01", from: "Capteur disponible"
    click_button "Attribuer le capteur"
    assert_selector "[data-garden-target='temp']", text: "24°C"
    assert_selector ".sensor-item", count: 1
    click_button "Zone 1"
    assert_select "Capteur disponible", options: [ "Choisir un capteur", "Température · T-03" ]
    click_button "Zone 3"
    click_button "Supprimer la zone"
    click_button "Zone 1"
    select "Température · T-01", from: "Capteur disponible"
    click_button "Attribuer le capteur"
    assert_selector ".sensor-item", count: 3
    assert_selector "[data-garden-target='temp']", text: "24°C"
  end

  test "Jardin follows the app theme and keeps the shared navigation icons" do
    dark_card = page.evaluate_script("getComputedStyle(document.querySelector('.garden-card')).backgroundColor")
    navigation_script = <<~JS
      (() => {
        const nav = document.querySelector('.navbar');
        const logo = nav.querySelector('a svg');
        return [getComputedStyle(nav).backgroundColor, getComputedStyle(logo).fill];
      })()
    JS
    garden_navigation = page.evaluate_script(navigation_script)
    assert_not_equal "none", garden_navigation.last
    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('a[href=\"/gardens\"] svg')).fill")
    assert_not_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('a[href=\"/gardens\"] svg')).stroke")

    page.execute_script("document.documentElement.dataset.theme = 'light'")
    light_card = page.evaluate_script("getComputedStyle(document.querySelector('.garden-card')).backgroundColor")
    assert_not_equal dark_card, light_card
    page.execute_script("document.documentElement.dataset.theme = 'dark'")
    assert_equal dark_card, page.evaluate_script("getComputedStyle(document.querySelector('.garden-card')).backgroundColor")

    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_selector ".home-page"
    assert_equal garden_navigation, page.evaluate_script(navigation_script)
  end

  test "presets can be created applied updated and deleted while zones keep independent snapshots" do
    fill_in "Nom du préréglage", with: "Summer"
    fill_in "Seuil d’humidité (%)", with: "40"
    fill_in "Seuil de température (°C)", with: "30"
    fill_in "Seuil de luminosité (lx)", with: "900"
    click_button "Enregistrer un nouveau préréglage"
    assert_select "Préréglage enregistré", selected: "Summer"

    click_button "Zone 2"
    assert_field "Seuil d’humidité (%)", with: ""
    select "Summer", from: "Préréglage enregistré"
    click_button "Appliquer le préréglage"
    assert_field "Seuil d’humidité (%)", with: "40"
    assert_field "Seuil de température (°C)", with: "30"
    assert_field "Seuil de luminosité (lx)", with: "900"
    fill_in "Seuil d’humidité (%)", with: "55"
    fill_in "Nom du préréglage", with: "Hot summer"
    click_button "Modifier le préréglage"

    click_button "Zone 1"
    assert_field "Seuil d’humidité (%)", with: "40"
    assert_select "Préréglage enregistré", selected: "Hot summer"
    click_button "Ajouter une zone"
    assert_field "Seuil d’humidité (%)", with: ""
    select "Hot summer", from: "Préréglage enregistré"
    click_button "Appliquer le préréglage"
    assert_field "Seuil d’humidité (%)", with: "55"
    page.refresh
    wait_for_garden
    assert_select "Préréglage enregistré", selected: "Hot summer"
    assert_field "Seuil d’humidité (%)", with: "55"

    click_button "Supprimer le préréglage"
    assert_select "Préréglage enregistré", options: [ "Choisir un préréglage" ]
    assert_field "Seuil d’humidité (%)", with: "55"
    page.refresh
    wait_for_garden
    assert_select "Préréglage enregistré", options: [ "Choisir un préréglage" ]
    click_button "Zone 1"
    assert_field "Seuil d’humidité (%)", with: "40"
  end

  test "presets reject empty names empty thresholds duplicates and out of range values" do
    click_button "Enregistrer un nouveau préréglage"
    assert_text "Saisissez un nom de préréglage"
    fill_in "Nom du préréglage", with: "Dry soil"
    click_button "Enregistrer un nouveau préréglage"
    assert_text "Saisissez au moins un seuil"
    fill_in "Seuil d’humidité (%)", with: "101"
    click_button "Enregistrer un nouveau préréglage"
    assert_text "Vérifiez les plages des seuils"
    assert_select "Préréglage enregistré", options: [ "Choisir un préréglage" ]

    fill_in "Seuil d’humidité (%)", with: "0"
    click_button "Enregistrer un nouveau préréglage"
    assert_select "Préréglage enregistré", selected: "Dry soil"
    click_button "Enregistrer un nouveau préréglage"
    assert_text "Un autre préréglage utilise déjà ce nom"
    page.refresh
    wait_for_garden
    assert_field "Seuil d’humidité (%)", with: "0"
    assert_field "Seuil de température (°C)", with: ""
    assert_select "Préréglage enregistré", options: [ "Choisir un préréglage", "Dry soil" ]
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
      raise Capybara::ElementNotFound, "Jardin controller has not connected" unless connected
    end
  end
end
