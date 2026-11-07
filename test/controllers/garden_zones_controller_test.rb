require "test_helper"

class GardenZonesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = users(:one)
    @other = users(:two)
    @zone = @owner.zones.create!(name: "Potager")
    @other_zone = @other.zones.create!(name: "Jardin privé")
  end

  test "all endpoints require authentication" do
    get garden_zones_path, as: :json
    assert_response :unauthorized

    assert_no_difference "Zone.count" do
      post garden_zones_path, params: { zone: { name: "Zone 1" } }, as: :json
      assert_response :unauthorized
      delete garden_zone_path(@zone), as: :json
      assert_response :unauthorized
    end

    patch garden_zone_path(@zone), params: { zone: { name: "Renamed" } }, as: :json
    assert_response :unauthorized
    assert_equal "Potager", @zone.reload.name
  end

  test "lists only the current account zones without exposing user attributes" do
    sign_in @owner
    get garden_zones_path, as: :json

    assert_response :success
    assert_equal [ @zone.garden_data.deep_stringify_keys ], response.parsed_body
  end

  test "creates a zone for the current user and ignores a forged owner or identifier" do
    sign_in @owner

    assert_difference "@owner.zones.count", 1 do
      assert_no_difference "@other.zones.count" do
        post garden_zones_path,
          params: { zone: { name: "  Zone 1  ", user_id: @other.id, id: @other_zone.id } }, as: :json
      end
    end

    assert_response :created
    assert_equal "Zone 1", response.parsed_body["name"]
    assert_equal @owner, Zone.find(response.parsed_body["id"]).user
  end

  test "rejects blank long and duplicate names without persisting invalid zones" do
    sign_in @owner

    [ "   ", "a" * 61, "POTAGER" ].each do |name|
      assert_no_difference "Zone.count" do
        post garden_zones_path, params: { zone: { name: name } }, as: :json
      end
      assert_response :unprocessable_entity
      assert response.parsed_body["errors"].present?
    end
  end

  test "renames an owned zone while retaining its owner and identifier" do
    sign_in @owner
    patch garden_zone_path(@zone),
      params: { zone: { name: "Serre", user_id: @other.id } }, as: :json

    assert_response :success
    assert_equal "Serre", @zone.reload.name
    assert_equal @owner.id, @zone.user_id
    assert_equal @zone.id, response.parsed_body["id"]
  end

  test "invalid renaming leaves the stored name unchanged" do
    sign_in @owner
    patch garden_zone_path(@zone), params: { zone: { name: " " } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Potager", @zone.reload.name
  end

  test "deletes only the owned zone" do
    sign_in @owner

    assert_difference "Zone.count", -1 do
      delete garden_zone_path(@zone), as: :json
    end

    assert_response :no_content
    assert Zone.exists?(@other_zone.id)
  end

  test "other accounts zones and missing zones cannot be renamed or deleted" do
    sign_in @owner

    [ @other_zone.id, Zone.maximum(:id) + 1 ].each do |id|
      patch garden_zone_path(id), params: { zone: { name: "Intrusion" } }, as: :json
      assert_response :not_found

      assert_no_difference "Zone.count" do
        delete garden_zone_path(id), as: :json
      end
      assert_response :not_found
    end
    assert_equal "Jardin privé", @other_zone.reload.name
  end

  test "Garden embeds only the signed in users zones and prevents snapshot caching" do
    sign_in @owner
    get gardens_path

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_select ".zone-btn", text: "Potager", count: 1
    assert_select ".zone-btn", text: "Jardin privé", count: 0
    assert_select "section[data-garden-account-id-value=?]", @owner.id.to_s
    assert_select "section[data-garden-zones-value]" do |elements|
      assert_equal [ @zone.garden_data.deep_stringify_keys ],
        JSON.parse(elements.first["data-garden-zones-value"])
    end
  end

  test "persists zone settings and returns the same values in subsequent requests" do
    sign_in @owner
    patch garden_zone_path(@zone), params: { zone: {
      crop: "Strawberries", schedule: "Every day - 7:00 AM",
      thresholds: { humidity: 45.5, temperature: -10, brightness: 1200 }
    } }, as: :json

    assert_response :success
    assert_equal "Strawberries", @zone.reload.crop
    assert_equal "Every day - 7:00 AM", @zone.schedule
    assert_equal({ humidity: 45.5, temperature: -10.0, brightness: 1200.0 }, @zone.thresholds)

    get garden_zones_path, as: :json
    assert_equal [ @zone.garden_data.deep_stringify_keys ], response.parsed_body

    patch garden_zone_path(@zone), params: { zone: { thresholds: { humidity: nil } } }, as: :json
    assert_response :success
    assert_nil @zone.reload.humidity_threshold
    assert_equal(-10.0, @zone.temperature_threshold)
  end

  test "invalid settings are rejected atomically" do
    sign_in @owner
    [ { crop: "Unknown" }, { schedule: "Unsupported" },
      { thresholds: { humidity: 101 } }, { thresholds: { temperature: -51 } },
      { thresholds: { brightness: 200_001 } }, { thresholds: { humidity: "wrong" } } ].each do |settings|
      original = @zone.reload.garden_data
      patch garden_zone_path(@zone), params: { zone: settings.merge(name: "Changed") }, as: :json
      assert_response :unprocessable_entity
      assert_equal original, @zone.reload.garden_data
    end
  end

  test "settings cannot be changed by another account" do
    sign_in @other
    original = @zone.garden_data
    patch garden_zone_path(@zone), params: { zone: { crop: "Strawberries", thresholds: { humidity: 40 } } }, as: :json

    assert_response :not_found
    assert_equal original, @zone.reload.garden_data
  end
end
