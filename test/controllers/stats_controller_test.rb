require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "statistics and daily details clearly display demo data" do
    get stats_path
    assert_response :success
    assert_select ".stats-note", text: /Données de démonstration/
    assert_select ".stats-list .stats-card", count: 5

    get stat_path("01-01-2026")
    assert_response :success
    assert_select "#stats-title", text: "01/01/2026"
    assert_select ".stats-table tbody tr", count: 8
    assert_select ".stats-section", count: 4
    assert_includes response.body, "33,5 L"
  end

  test "an unknown day redirects to the statistics list" do
    get stat_path("31-02-2026")
    assert_redirected_to stats_path
  end
end
