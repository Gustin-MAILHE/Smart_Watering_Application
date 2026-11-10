require "application_system_test_case"

class GardenStepsTest < ApplicationSystemTestCase
  setup do
    visit gardens_path
    assert_field "Nom de la zone"
    page.execute_script("localStorage.clear()")
    page.refresh
    assert_field "Nom de la zone"
  end

  test "arrival reveals only cultures and visitors can move forward and back with the keyboard" do
    assert_selector "[data-garden-steps-target=panel]", count: 1
    assert_no_field "Date de début"
    assert_no_select "Capteur disponible"
    assert_no_field "Nom du préréglage"
    assert_button "← Étape précédente", disabled: true
    select "Fraises", from: "Cultures"

    find(".garden-next").send_keys(:enter)
    assert_select "Capteur disponible", disabled: true
    assert_no_select "Cultures"
    assert_selector "[data-garden-steps-target=panel]", count: 1
    assert_equal "garden-step-heading-2", page.evaluate_script("document.activeElement.id")
    click_button "← Étape précédente"
    assert_select "Cultures", selected: "Fraises"
    assert_no_select "Capteur disponible"
  end

  test "leaving watering validates and saves its draft before showing the next step" do
    garden_step "Arrosage"
    click_button "Ajouter un créneau"
    click_button "Enregistrer et continuer →"
    assert_selector ".garden-step-button[aria-current=step]", text: "Arrosage"
    assert_selector "[data-garden-target=wateringError]", text: "Vérifiez les créneaux"
    set_time "Début du créneau 2", "18:00"
    set_time "Fin du créneau 2", "18:20"
    click_button "Enregistrer et continuer →"
    assert_field "Nom du préréglage"
    assert_no_field "Date de début"
    assert_no_selector ".garden-next"
    click_button "← Étape précédente"
    assert_field "Fin du créneau 2", with: "18:20"
    page.refresh
    assert_select "Cultures"
    garden_step "Arrosage"
    assert_field "Fin du créneau 2", with: "18:20"
  end

  test "a failed save keeps the watering step open and displays the error beside the fields" do
    zone = users(:one).zones.create!(name: "Serre")
    visit new_user_session_path
    fill_in "Adresse e-mail", with: users(:one).email
    fill_in "Mot de passe", with: "GardenTest123!"
    click_button "Se connecter"
    assert_current_path root_path
    visit gardens_path
    garden_step "Arrosage"
    set_time "Fin du créneau 1", "20:45"
    page.execute_script("window.fetch = () => Promise.reject(new TypeError('Offline'))")
    click_button "Enregistrer et continuer →"
    assert_selector ".garden-step-button[aria-current=step]", text: "Arrosage"
    assert_selector "[data-garden-target=wateringError]", text: "Impossible de joindre le serveur"
    assert_field "Fin du créneau 1", with: "20:30"
    assert_equal "20:30", zone.reload.watering_time_slots.first["end"]
  end

  test "the entire journey fits exact phone and desktop viewports in both themes" do
    [ 320, 390, 1280 ].each do |width|
      page.execute_script(<<~JS, gardens_path, width)
        document.getElementById('steps-preview')?.remove();
        const frame = document.createElement('iframe');
        frame.id = 'steps-preview';
        frame.src = arguments[0];
        frame.style.cssText = `width:${arguments[1]}px;height:2000px;border:0;position:fixed;top:0;left:0;z-index:200`;
        document.body.append(frame);
      JS
      within_frame "steps-preview" do
        [ "light", "dark" ].each do |theme|
          page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme)
          %w[Cultures Capteurs Arrosage Seuils].each do |step|
            garden_step step
            assert_equal width, page.evaluate_script("innerWidth")
            assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "Overflow at #{width}px / #{theme} / #{step}"
            assert_selector "[data-garden-steps-target=panel]", count: 1
          end
        end
      end
    end
  end

  private

  def set_time(label, value)
    page.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", find_field(label), value)
  end
end
