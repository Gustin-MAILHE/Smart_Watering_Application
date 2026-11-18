require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "demo accounts never expose or store a submitted password" do
    get accounts_path
    assert_response :success
    assert_includes response.body, "ces comptes fictifs"
    assert_no_match(/motdepasse[123]/, response.body)
    assert_select "input[type=password]", count: 3

    patch account_path(1), params: { password: "DemoPassword123!" }
    assert_redirected_to accounts_path
    assert session[:users].first["password_changed"]
    assert_not session[:users].any? { |user| user.key?("password") }
    follow_redirect!
    assert_includes response.body, "Modifié en démonstration"
    assert_not_includes response.body, "DemoPassword123!"
  end

  test "editing and deleting demo accounts leaves registered users unchanged" do
    original_accounts = User.pluck(:id, :email, :encrypted_password)
    patch account_path(1), params: { role: "user" }
    delete account_path(2)

    assert_redirected_to accounts_path
    assert_equal original_accounts, User.pluck(:id, :email, :encrypted_password)
    follow_redirect!
    assert_select ".account-card", count: 2
  end
end
