require "application_system_test_case"

class AccountGardensTest < ApplicationSystemTestCase
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
  end

  test "account zones survive browser storage removal and support creation renaming and deletion" do
    users(:one).zones.create!(name: "Serre")
    login(users(:one))
    visit gardens_path
    assert_button "Serre"
    assert_no_button "Zone 2"

    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 1"
    assert_equal 2, users(:one).zones.count
    fill_in "Nom de la zone", with: "Potager"
    click_button "Enregistrer le nom"
    assert_selector ".zone-btn.active", text: "Potager"
    assert users(:one).zones.exists?(name: "Potager")

    page.execute_script("window.localStorage.clear()")
    page.refresh
    assert_button "Serre"
    assert_button "Potager"
    click_button "Potager"
    page.execute_script("window.confirm = () => { throw new Error('Unexpected confirmation') }")
    click_button "Supprimer la zone"
    assert_no_button "Potager"
    assert_equal [ "Serre" ], users(:one).zones.pluck(:name)

    page.refresh
    assert_button "Serre"
    assert_no_button "Potager"
    click_button "Supprimer la zone"
    assert_text "Aucune zone pour le moment"
    page.refresh
    assert_text "Aucune zone pour le moment"
    assert_no_selector ".zone-btn"
  end

  test "accounts with the same zone name keep separate zones and saved configuration" do
    users(:one).zones.create!(name: "Zone 1")
    users(:two).zones.create!(name: "Zone 1")
    login(users(:one))
    visit gardens_path
    assert_button "Zone 1"
    select "Fraises", from: "Cultures"
    wait_for_save
    fill_in "Seuil d’humidité (%)", with: "45"
    find("#humidity-threshold").send_keys(:tab)
    wait_for_save
    logout

    login(users(:two))
    visit gardens_path
    assert_button "Zone 1"
    assert_select "Cultures", selected: "Carottes"
    assert_field "Seuil d’humidité (%)", with: ""
    fill_in "Nom de la zone", with: "Zone privée"
    click_button "Enregistrer le nom"
    assert_button "Zone privée"
    logout

    login(users(:one))
    visit gardens_path
    assert_button "Zone 1"
    assert_no_button "Zone privée"
    assert_select "Cultures", selected: "Fraises"
    assert_field "Seuil d’humidité (%)", with: "45"
  end

  test "an empty account does not import the anonymous demo" do
    visit gardens_path
    assert_button "Zone 1"
    click_button "Ajouter une zone"
    assert_button "Zone 3"

    login(users(:one))
    visit gardens_path
    assert_text "Aucune zone pour le moment"
    assert_no_selector ".zone-btn"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 1"
    assert_equal 1, users(:one).zones.count
    logout

    visit gardens_path
    assert_button "Zone 3"
  end

  test "a network failure leaves the displayed and stored zones unchanged" do
    users(:one).zones.create!(name: "Serre")
    login(users(:one))
    visit gardens_path
    assert_button "Serre"
    page.execute_script("window.fetch = () => Promise.reject(new TypeError('Offline'))")

    click_button "Ajouter une zone"
    assert_text "Impossible de joindre le serveur"
    assert_selector ".zone-btn", count: 1
    click_button "Supprimer la zone"
    assert_text "Impossible de joindre le serveur"
    assert_button "Serre"
    fill_in "Nom de la zone", with: "Potager"
    click_button "Enregistrer le nom"
    assert_text "Impossible de joindre le serveur"
    assert_button "Serre"
    assert_equal [ "Serre" ], users(:one).zones.pluck(:name)
  end

  test "Turbo navigation retrieves updated server zones and account creation works without local storage" do
    login(users(:one))
    visit gardens_path
    assert_text "Aucune zone pour le moment"
    page.execute_script("Storage.prototype.setItem = () => { throw new DOMException('Full', 'QuotaExceededError') }")
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 1"
    assert_text "Les zones sont enregistrées sur votre compte, mais"

    page.execute_script("window.Turbo.visit(arguments[0])", root_path)
    assert_selector ".home-page"
    users(:one).zones.find_by!(name: "Zone 1").update!(name: "Renommée ailleurs")
    page.go_back
    assert_button "Renommée ailleurs"
    assert_no_button "Zone 1"
  end

  test "a missing CSRF token rejects creation without changing the garden" do
    login(users(:one))
    visit gardens_path
    assert_text "Aucune zone pour le moment"
    page.execute_script("document.querySelector('meta[name=csrf-token]').remove()")

    click_button "Ajouter une zone"
    assert_text "Impossible d’enregistrer la modification"
    assert_no_selector ".zone-btn"
    assert_equal 0, users(:one).zones.count
  end

  test "zone configuration survives clearing browser storage while other zones retain their settings" do
    first = users(:one).zones.create!(name: "Potager")
    users(:one).zones.create!(name: "Serre")
    login(users(:one))
    visit gardens_path
    click_button "Potager"
    select "Fraises", from: "Cultures"
    wait_for_save
    select "Tous les jours à 07 h 00", from: "Programme d’arrosage"
    wait_for_save
    fill_in "Seuil d’humidité (%)", with: "45"
    find("#humidity-threshold").send_keys(:tab)
    wait_for_save
    fill_in "Seuil de température (°C)", with: "28"
    find("#temperature-threshold").send_keys(:tab)
    wait_for_save
    fill_in "Seuil de luminosité (lx)", with: "1500"
    find("#brightness-threshold").send_keys(:tab)
    wait_for_save
    assert_equal({ humidity: 45.0, temperature: 28.0, brightness: 1500.0 }, first.reload.thresholds)

    page.execute_script("localStorage.clear()")
    page.refresh
    click_button "Potager"
    assert_select "Cultures", selected: "Fraises"
    assert_select "Programme d’arrosage", selected: "Tous les jours à 07 h 00"
    assert_field "Seuil d’humidité (%)", with: "45"
    assert_field "Seuil de température (°C)", with: "28"
    assert_field "Seuil de luminosité (lx)", with: "1500"
    click_button "Serre"
    assert_select "Cultures", selected: "Carottes"
    assert_field "Seuil d’humidité (%)", with: ""
  end

  test "legacy account configuration can be transferred without trusting stale settings after transfer" do
    zone = users(:one).zones.create!(name: "Potager")
    zone.update_column(:configuration_saved, false)
    login(users(:one))
    visit gardens_path
    state = {
      version: 1, numberingVersion: 1, selectedZoneId: zone.id, zones: [ {
        id: zone.id, name: "Potager", crop: "Strawberries", schedule: "Every day - 7:00 AM", sensorIds: [],
        thresholds: { humidity: 42, temperature: nil, brightness: nil }
      } ]
    }
    page.execute_script("localStorage.setItem(arguments[0], arguments[1])", account_storage_key, state.to_json)
    page.refresh
    assert_button "Enregistrer ces réglages sur mon compte"
    assert_select "Cultures", selected: "Fraises"
    assert_field "Seuil d’humidité (%)", with: "42"
    assert_equal "Carrots", zone.reload.crop

    click_button "Enregistrer ces réglages sur mon compte"
    assert_no_button "Enregistrer ces réglages sur mon compte"
    assert zone.reload.configuration_saved
    assert_equal "Strawberries", zone.crop
    state[:zones][0][:crop] = "Lettuce"
    state[:zones][0][:thresholds][:humidity] = 1
    page.execute_script("localStorage.setItem(arguments[0], arguments[1])", account_storage_key, state.to_json)
    page.refresh
    assert_select "Cultures", selected: "Fraises"
    assert_field "Seuil d’humidité (%)", with: "42"
    assert_no_button "Enregistrer ces réglages sur mon compte"

    page.execute_script("localStorage.clear()")
    page.refresh
    assert_select "Cultures", selected: "Fraises"
    assert_field "Seuil d’humidité (%)", with: "42"
  end

  test "configuration failures restore confirmed values instead of displaying unsaved settings" do
    zone = users(:one).zones.create!(name: "Potager", thresholds: { humidity: 30 })
    login(users(:one))
    visit gardens_path
    assert_field "Seuil d’humidité (%)", with: "30"
    page.execute_script("window.fetch = () => Promise.reject(new TypeError('Offline'))")
    select "Fraises", from: "Cultures"
    assert_text "Impossible de joindre le serveur"
    assert_select "Cultures", selected: "Carottes"
    fill_in "Seuil d’humidité (%)", with: "45"
    find("#humidity-threshold").send_keys(:tab)
    assert_field "Seuil d’humidité (%)", with: "30"
    assert_equal "Carrots", zone.reload.crop
    assert_equal 30, zone.humidity_threshold
  end

  test "applied preset thresholds are saved independently from the browser preset library" do
    users(:one).zones.create!(name: "Potager")
    login(users(:one))
    visit gardens_path
    fill_in "Nom du préréglage", with: "Été"
    fill_in "Seuil d’humidité (%)", with: "40"
    find("#humidity-threshold").send_keys(:tab)
    wait_for_save
    click_button "Enregistrer un nouveau préréglage"
    assert_select "Préréglage enregistré", selected: "Été"
    click_button "Ajouter une zone"
    assert_selector ".zone-btn.active", text: "Zone 1"
    select "Été", from: "Préréglage enregistré"
    click_button "Appliquer le préréglage"
    wait_for_save
    assert_field "Seuil d’humidité (%)", with: "40"
    page.execute_script("localStorage.clear()")
    page.refresh
    click_button "Zone 1"
    assert_field "Seuil d’humidité (%)", with: "40"
    assert_select "Préréglage enregistré", options: [ "Choisir un préréglage" ]
  end

  private

  def account_storage_key
    "smartWatering.garden.v1.account.#{users(:one).id}"
  end

  def wait_for_save
    assert_no_selector "[data-controller=garden][aria-busy=true]"
  end

  def login(user)
    visit new_user_session_path
    fill_in "Adresse e-mail", with: user.email
    fill_in "Mot de passe", with: "GardenTest123!"
    click_button "Se connecter"
    assert_current_path root_path
  end

  def logout
    find("#open-menu").click
    click_button "Se déconnecter"
    assert_current_path root_path
  end
end
