require "test_helper"

# Ensures account forms and server-side feedback use the application's French locale.
class LocalizationTest < ActionDispatch::IntegrationTest
  test "login labels and authentication errors are displayed in French" do
    get new_user_session_path
    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "label[for=user_email]", text: "Adresse e-mail"
    assert_select "label[for=user_password]", text: "Mot de passe"
    assert_select "button[type=submit]", text: "Se connecter"

    post user_session_path, params: { user: { email: "missing@example.test", password: "incorrect" } }
    follow_redirect! if response.redirect?
    assert_includes response.body, "Adresse e-mail ou mot de passe incorrect."
    assert_no_match(/translation missing/i, response.body)
  end

  test "account validation attributes and messages are translated" do
    user = User.new(email: "invalid", password: "x", password_confirmation: "y")
    assert_not user.valid?
    assert_includes user.errors.full_messages.join(" "), "Adresse e-mail"
    assert_includes user.errors.full_messages.join(" "), "n’est pas valide"
    assert_includes user.errors.full_messages.join(" "), "Mot de passe"
    assert_no_match(/translation missing/i, user.errors.full_messages.join(" "))
  end
end
