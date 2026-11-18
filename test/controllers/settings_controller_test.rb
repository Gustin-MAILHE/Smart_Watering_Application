require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "only signed in users can save unit preferences" do
    post update_preferences_path, params: { temperature_unit: "kelvin" }
    assert_redirected_to new_user_session_path
    assert_equal "celsius", users(:one).reload.temperature_unit
  end

  test "preference updates affect only allowed fields on the current account" do
    sign_in users(:one)
    post update_preferences_path, params: {
      temperature_unit: "kelvin", humidity_unit: "weight_by_distance", brightness_unit: "lux",
      id: users(:two).id, email: "changed@example.test"
    }

    assert_redirected_to root_path
    assert_equal "kelvin", users(:one).reload.temperature_unit
    assert_equal "lux", users(:one).brightness_unit
    assert_equal "weight_by_distance", users(:one).humidity_unit
    assert_not_equal "changed@example.test", users(:one).email
    assert_equal "celsius", users(:two).reload.temperature_unit
  end

  test "invalid preferences reject the whole update" do
    sign_in users(:one)
    post update_preferences_path, params: { temperature_unit: "kelvin", brightness_unit: "invalid" }

    assert_redirected_to root_path
    assert_equal "celsius", users(:one).reload.temperature_unit
    assert_equal "percentage", users(:one).brightness_unit
    assert_equal "Erreur lors de la mise à jour.", flash[:alert]
  end
end
