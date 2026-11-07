require "test_helper"

class ZoneTest < ActiveSupport::TestCase
  test "persists a zone for its owner and trims its name" do
    zone = users(:one).zones.create!(name: "  Potager  ")

    assert_equal "Potager", zone.reload.name
    assert_equal users(:one), zone.user
  end

  test "requires an existing owner" do
    zone = Zone.new(name: "Potager")
    assert_not zone.valid?
    assert zone.errors.of_kind?(:user, :blank)

    zone.user_id = User.maximum(:id) + 1
    assert_not zone.valid?
    assert zone.errors.of_kind?(:user, :blank)
  end

  test "rejects blank and overly long names" do
    [ nil, "", "   ", "a" * 61 ].each do |name|
      zone = users(:one).zones.build(name: name)
      assert_not zone.valid?
      assert zone.errors[:name].present?
    end

    assert users(:one).zones.build(name: "a" * 60).valid?
  end

  test "rejects duplicate names for the same owner regardless of case and surrounding spaces" do
    users(:one).zones.create!(name: "Potager")
    duplicate = users(:one).zones.build(name: "  POTAGER  ")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  test "allows the same name for different owners without mixing their zones" do
    first = users(:one).zones.create!(name: "Zone 1")
    second = users(:two).zones.create!(name: "Zone 1")

    assert_equal [ first ], users(:one).zones.to_a
    assert_equal [ second ], users(:two).zones.to_a
    assert_raises(ActiveRecord::RecordNotFound) { users(:one).zones.find(second.id) }
  end

  test "deleting an owner removes only their zones" do
    owned = users(:one).zones.create!(name: "Zone 1")
    other = users(:two).zones.create!(name: "Zone 1")

    assert_difference "Zone.count", -1 do
      users(:one).destroy!
    end

    assert_not Zone.exists?(owned.id)
    assert Zone.exists?(other.id)
  end

  test "database prevents duplicate names even when validations are bypassed" do
    users(:one).zones.create!(name: "Potager")
    duplicate = users(:one).zones.build(name: "POTAGER")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "database prevents zones referencing a nonexistent owner" do
    zone = Zone.new(name: "Potager", user_id: User.maximum(:id) + 1)

    assert_raises(ActiveRecord::InvalidForeignKey) { zone.save!(validate: false) }
  end

  test "threshold limits include the boundaries and allow disabled thresholds" do
    zone = users(:one).zones.build(name: "Limites")
    [ [ 0, -50, 0 ], [ 100, 100, 200_000 ], [ nil, nil, nil ] ].each do |humidity, temperature, brightness|
      zone.thresholds = { humidity: humidity, temperature: temperature, brightness: brightness }
      assert zone.valid?, zone.errors.full_messages.join(", ")
    end

    { humidity_threshold: [ -1, 101, "invalid", Float::INFINITY ],
      temperature_threshold: [ -51, 101 ], brightness_threshold: [ -1, 200_001 ] }.each do |field, values|
      values.each do |value|
        zone.assign_attributes(humidity_threshold: nil, temperature_threshold: nil, brightness_threshold: nil)
        zone.public_send("#{field}=", value)
        assert_not zone.valid?, "#{field}=#{value} must be rejected"
      end
    end
  end

  test "renaming legacy zones does not mark unsaved configuration as transferred" do
    zone = users(:one).zones.create!(name: "Ancienne zone")
    zone.update_column(:configuration_saved, false)
    zone.update!(name: "Nouveau nom")
    assert_not zone.reload.configuration_saved

    zone.update!(thresholds: { humidity: nil, temperature: nil, brightness: nil })
    assert zone.reload.configuration_saved
  end
end
