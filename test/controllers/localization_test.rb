require "test_helper"

# Ensures account forms and server-side feedback use the application's French locale.
class LocalizationTest < ActionDispatch::IntegrationTest
  test "language changes persist without leaking into other requests" do
    original_locale = I18n.locale
    post set_language_path, params: { locale: "en" }
    follow_redirect!
    assert_select "html[lang=en]"
    assert_equal original_locale, I18n.locale

    get settings_path
    assert_select "html[lang=en]"
    open_session do |other_browser|
      other_browser.get settings_path
      other_browser.assert_select "html[lang=fr]"
    end
  end

  test "unsupported or malformed languages preserve the last valid choice" do
    post set_language_path, params: { locale: "en" }

    [ "unknown", "", [ "fr" ], { code: "fr" } ].each do |locale|
      post set_language_path, params: { locale: locale }
      follow_redirect!
      assert_response :success
      assert_select "html[lang=en]"
    end
  end

  test "an unsupported language defaults to French for a new visitor" do
    get root_path, params: { locale: "unknown" }
    assert_response :success
    assert_select "html[lang=fr]"
  end

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
