require "application_system_test_case"

class PasswordRecoverySystemTest < ApplicationSystemTestCase
  test "a visitor can request a recovery email and reset their password using its link" do
    ActionMailer::Base.deliveries.clear
    visit new_user_session_path
    click_link "Mot de passe oublié ?"
    assert_current_path new_user_password_path
    click_button "Recevoir le lien"
    assert_equal "Saisissez votre adresse e-mail.", find_field("Adresse e-mail").evaluate_script("this.validationMessage")
    fill_in "Adresse e-mail", with: "invalide"
    click_button "Recevoir le lien"
    assert_equal "Saisissez une adresse e-mail valide, par exemple nom@exemple.fr.", find_field("Adresse e-mail").evaluate_script("this.validationMessage")
    fill_in "Adresse e-mail", with: users(:one).email
    click_button "Recevoir le lien"
    assert_current_path new_user_session_path
    assert_text "Si votre adresse e-mail est enregistrée"

    message = ActionMailer::Base.deliveries.last
    assert_not_nil message
    link = Nokogiri::HTML(message.body.decoded).at_css("a")["href"]
    visit URI.parse(link).request_uri
    assert_field "Nouveau mot de passe"
    fill_in "Nouveau mot de passe", with: "NewGarden456!"
    fill_in "Confirmer le nouveau mot de passe", with: "NewGarden456!"
    click_button "Afficher les mots de passe"
    assert_selector "#user_password[type=text]"
    assert_selector "button[aria-pressed=true]", text: "Masquer les mots de passe"
    click_button "Masquer les mots de passe"
    assert_selector "#user_password[type=password]"
    click_button "Modifier mon mot de passe"
    assert_current_path root_path
    assert_text "Votre mot de passe a été modifié"
    assert users(:one).reload.valid_password?("NewGarden456!")
    assert_not users(:one).valid_password?("GardenTest123!")
  end
end
