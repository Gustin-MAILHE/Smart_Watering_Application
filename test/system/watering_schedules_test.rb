require "application_system_test_case"

class WateringSchedulesTest < ApplicationSystemTestCase
  setup do
    visit gardens_path
    garden_step "Arrosage"
    assert_selector ".watering-slot"
    page.execute_script("localStorage.clear()")
    page.refresh
    garden_step "Arrosage"
    assert_field "Début du créneau 1", with: "06:00"
  end

  test "demo slots and dates can be added edited removed and cleared independently for each zone" do
    garden_step "Arrosage"
    set_field "Début du créneau 1", "05:45"
    set_field "Fin du créneau 1", "06:10"
    click_button "Ajouter un créneau"
    set_field "Début du créneau 2", "19:00"
    set_field "Fin du créneau 2", "19:20"
    set_field "Date de début", "2027-05-01"
    set_field "Date de fin", "2027-08-31"
    save_schedule
    assert_text "Créneaux et dates appliqués en mode démonstration."
    set_field "Fin du créneau 2", "19:25"
    assert_no_text "Créneaux et dates appliqués en mode démonstration."
    set_field "Fin du créneau 2", "19:20"
    select "Tous les jours", from: "Fréquence d’arrosage"
    click_button "Zone 2"
    assert_selector ".watering-slot", count: 1
    assert_field "Début du créneau 1", with: "07:00"
    assert_field "Date de début", with: ""
    click_button "Zone 1"
    page.refresh
    garden_step "Arrosage"
    assert_field "Début du créneau 1", with: "05:45"
    assert_field "Fin du créneau 2", with: "19:20"
    assert_field "Date de début", with: "2027-05-01"
    assert_field "Date de fin", with: "2027-08-31"
    assert_select "Fréquence d’arrosage", selected: "Tous les jours"

    find("button[aria-label='Supprimer le créneau 1']").click
    assert_field "Début du créneau 1", with: "19:00"
    set_field "Date de début", ""
    set_field "Date de fin", ""
    save_schedule
    page.refresh
    garden_step "Arrosage"
    assert_selector ".watering-slot", count: 1
    assert_field "Fin du créneau 1", with: "19:20"
    assert_field "Date de début", with: ""
    assert_field "Date de fin", with: ""
  end

  test "invalid drafts never replace a saved watering schedule" do
    garden_step "Arrosage"
    click_button "Ajouter un créneau"
    save_schedule
    assert_selector "[data-garden-target=wateringError]", text: "Vérifiez les créneaux"
    set_field "Début du créneau 2", "06:15"
    set_field "Fin du créneau 2", "07:00"
    save_schedule
    assert_selector "[data-garden-target=wateringError]", text: "sans chevauchement"
    set_field "Début du créneau 2", "23:00"
    set_field "Fin du créneau 2", "01:00"
    save_schedule
    assert_selector "[data-garden-target=wateringError]", text: "une fin après le début"
    set_field "Début du créneau 2", "18:00"
    set_field "Fin du créneau 2", "18:30"
    set_field "Date de début", "2027-06-01"
    set_field "Date de fin", "2027-05-01"
    save_schedule
    assert_selector "[data-garden-target=wateringError]", text: "La date de fin"
    page.refresh
    garden_step "Arrosage"
    assert_selector ".watering-slot", count: 1
    assert_field "Début du créneau 1", with: "06:00"
    assert_field "Date de début", with: ""
    find("button[aria-label='Supprimer le créneau 1']").click
    save_schedule
    assert_selector "[data-garden-target=wateringError]", text: "1 à 24 horaires"
  end

  test "account schedules survive browser storage removal without affecting another zone or account" do
    zone = users(:one).zones.create!(name: "Potager")
    users(:one).zones.create!(name: "Serre")
    other = users(:two).zones.create!(name: "Potager")
    login(users(:one))
    click_button "Potager"
    garden_step "Arrosage"
    set_field "Début du créneau 1", "08:00"
    set_field "Fin du créneau 1", "08:15"
    set_field "Date de début", "2027-04-01"
    set_field "Date de fin", "2027-09-30"
    save_schedule
    assert_text "Créneaux et dates enregistrés sur votre compte."
    assert_equal [ { "start" => "08:00", "end" => "08:15" } ], zone.reload.watering_time_slots
    assert_equal Date.new(2027, 4, 1), zone.watering_starts_on
    assert_nil other.reload.watering_starts_on
    page.execute_script("localStorage.clear()")
    page.refresh
    click_button "Potager"
    garden_step "Arrosage"
    assert_field "Début du créneau 1", with: "08:00"
    assert_field "Date de fin", with: "2027-09-30"
    click_button "Serre"
    assert_field "Début du créneau 1", with: "20:00"
    assert_field "Date de début", with: ""
  end

  test "a failed account save restores confirmed slots and dates" do
    zone = users(:one).zones.create!(name: "Potager")
    login(users(:one))
    garden_step "Arrosage"
    assert_field "Début du créneau 1", with: "20:00"
    page.execute_script("window.fetch = () => Promise.reject(new TypeError('Offline'))")
    set_field "Début du créneau 1", "09:00"
    set_field "Fin du créneau 1", "09:15"
    set_field "Date de début", "2027-04-01"
    save_schedule
    assert_text "Impossible de joindre le serveur"
    assert_field "Début du créneau 1", with: "20:00"
    assert_field "Date de début", with: ""
    assert_nil zone.reload.watering_starts_on
    assert_no_text "Créneaux et dates enregistrés"
  end

  test "legacy browser schedules gain editable slots without losing other settings" do
    state = {
      version: 1, numberingVersion: 1, selectedZoneId: 9,
      zones: [ { id: 9, name: "Ancienne zone", crop: "Strawberries", schedule: "Every day - 7:00 AM", sensorIds: [] } ]
    }
    page.execute_script("localStorage.setItem('smartWatering.garden.v1', arguments[0])", state.to_json)
    page.refresh
    assert_button "Ancienne zone"
    garden_step "Cultures"
    assert_select "Cultures", selected: "Fraises"
    garden_step "Arrosage"
    assert_field "Début du créneau 1", with: "07:00"
    assert_field "Fin du créneau 1", with: "07:30"
    save_schedule
    page.refresh
    garden_step "Arrosage"
    assert_field "Début du créneau 1", with: "07:00"
  end

  private

  # Native date/time fields use browser locale specific keyboard formats; assign their ISO values.
  def set_field(label, value)
    field = find_field(label)
    page.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", field, value)
  end

  def save_schedule
    garden_step "Arrosage"
    click_button "Enregistrer les créneaux et les dates"
  end

  def login(user)
    visit new_user_session_path
    fill_in "Adresse e-mail", with: user.email
    fill_in "Mot de passe", with: "GardenTest123!"
    click_button "Se connecter"
    assert_current_path root_path
    visit gardens_path
    garden_step "Arrosage"
    assert_selector ".watering-slot"
  end
end
