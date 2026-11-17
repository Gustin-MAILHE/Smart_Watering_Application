require "test_helper"

class PasswordRecoveryTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = users(:one)
    ActionMailer::Base.deliveries.clear
  end

  test "login links to recovery and its form accepts an email address" do
    get new_user_session_path
    assert_select "a[href=?]", new_user_password_path, text: "Mot de passe oublié ?"
    get new_user_password_path
    assert_response :success
    assert_select "form[action=?]", user_password_path
    assert_select "input[type=email][required][autocomplete=email]"
    assert_includes response.body, "valable 15 minutes"
  end

  test "known and unknown addresses receive the same response without exposing account existence" do
    assert_emails 1 do
      post user_password_path, params: { user: { email: @user.email } }
    end
    assert_redirected_to new_user_session_path
    notice = flash[:notice]
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), notice
    assert @user.reload.valid_password?("GardenTest123!")
    assert_not_equal reset_token, @user.reset_password_token

    assert_no_emails do
      post user_password_path, params: { user: { email: "missing@example.test" } }
    end
    assert_redirected_to new_user_session_path
    assert_equal notice, flash[:notice]
  end

  test "email contains a working single use link and the old password stops working after reset" do
    request_reset
    token = reset_token
    assert_equal [ @user.email ], ActionMailer::Base.deliveries.last.to
    assert_includes ActionMailer::Base.deliveries.last.body.decoded, "15 minutes"
    assert_equal "Réinitialisation de votre mot de passe — Arrosage intelligent", ActionMailer::Base.deliveries.last.subject
    get edit_user_password_path(reset_password_token: token)
    assert_response :success
    assert_select "input[type=hidden][name=?][value=?]", "user[reset_password_token]", token

    update_password(token)
    assert_redirected_to root_path
    assert @user.reload.valid_password?("NewGarden456!")
    assert_not @user.valid_password?("GardenTest123!")
    assert_nil @user.reset_password_token
    assert_nil @user.reset_password_sent_at

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: @user.email, password: "GardenTest123!" } }
    follow_redirect! if response.redirect?
    assert_includes response.body, I18n.t("devise.failure.invalid", authentication_keys: "Adresse e-mail")
    post user_session_path, params: { user: { email: @user.email, password: "NewGarden456!" } }
    assert_redirected_to root_path
    delete destroy_user_session_path

    update_password(token, "AnotherGarden789!")
    assert_response :unprocessable_entity
    assert @user.reload.valid_password?("NewGarden456!")
  end

  test "expired links cannot modify the password" do
    request_reset
    token = reset_token
    assert_equal 15.minutes, User.reset_password_within
    travel 16.minutes do
      update_password(token)
    end
    assert_response :unprocessable_entity
    assert @user.reload.valid_password?("GardenTest123!")
    assert_select "#error_explanation[role=alert]"
    assert_select "#error_explanation", text: /Lien de réinitialisation a expiré. Demandez un nouveau lien./
    assert_select "a[href=?]", new_user_password_path, text: "Demander un nouveau lien"
  end

  test "links remain valid just before the fifteen minute expiry" do
    request_reset
    token = reset_token
    travel 14.minutes do
      update_password(token)
      assert_redirected_to root_path
    end
    assert @user.reload.valid_password?("NewGarden456!")
  end

  test "invalid tokens and invalid passwords leave the account unchanged" do
    request_reset
    token = reset_token
    [ [ "invalid-token", "NewGarden456!", "NewGarden456!" ],
      [ token, "short", "short" ], [ token, "NewGarden456!", "Different789!" ] ].each do |value, password, confirmation|
      original = @user.reload.encrypted_password
      patch user_password_path, params: { user: {
        reset_password_token: value, password: password, password_confirmation: confirmation
      } }
      assert_response :unprocessable_entity
      assert_equal original, @user.reload.encrypted_password
      assert_select "#error_explanation[role=alert]"
    end
    update_password(token)
    assert_redirected_to root_path
  end

  test "requesting another link invalidates the previous link" do
    request_reset
    old_token = reset_token
    request_reset
    token = reset_token
    assert_not_equal old_token, token
    update_password(old_token)
    assert_response :unprocessable_entity
    update_password(token)
    assert_redirected_to root_path
  end

  test "opening recovery without a token explains how to obtain a link" do
    get edit_user_password_path
    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.passwords.no_token"), flash[:alert]
  end

  private

  def request_reset
    post user_password_path, params: { user: { email: @user.email } }
    assert_redirected_to new_user_session_path
  end

  def reset_token
    html = Nokogiri::HTML(ActionMailer::Base.deliveries.last.body.decoded)
    uri = URI.parse(html.at_css("a")["href"])
    assert_equal "/users/password/edit", uri.path
    Rack::Utils.parse_query(uri.query).fetch("reset_password_token")
  end

  def update_password(token, password = "NewGarden456!")
    patch user_password_path, params: { user: {
      reset_password_token: token, password: password, password_confirmation: password
    } }
  end
end
