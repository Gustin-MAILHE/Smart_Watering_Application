require "test_helper"

# Verifies Garden's integration with the shared layout and account navigation.
class GardensControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "Garden keeps the shared header footer and signed out navigation" do
    get gardens_path

    assert_response :success
    assert_select "main", count: 1
    assert_select "main .garden-wrapper", count: 1
    assert_select ".site-header nav li.active a[href=?]", gardens_path, count: 1
    assert_select ".site-header a[href=?] svg", gardens_path, count: 1
    assert_select ".site-header a[href=?]", new_user_session_path, count: 1
    assert_select ".site-footer", count: 1
  end

  test "Garden keeps signed in account information and logout" do
    sign_in users(:one)
    get gardens_path

    assert_response :success
    assert_select ".site-header strong", text: users(:one).username
    assert_select ".site-header form[action=?]", destroy_user_session_path, count: 1
    assert_select ".site-header a[href=?]", new_user_session_path, count: 0
  end

  test "initial sensor readings never expose zone thresholds as measurements" do
    users(:one).zones.create!(name: "Serre", thresholds: { temperature: 35, humidity: 65, brightness: 1500 })
    sign_in users(:one)
    get gardens_path

    assert_response :success
    %w[temp humidity brightness].each do |type|
      assert_select "[data-garden-target='#{type}']", text: "—"
    end
    assert_select "[data-garden-target=readingsNote]", text: "Aucune mesure disponible."
  end
end
