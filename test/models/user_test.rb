require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "unit preferences accept supported values and reject invalid input" do
    preferences = {
      temperature_unit: %w[celsius fahrenheit kelvin],
      brightness_unit: %w[percentage lumen lux],
      humidity_unit: %w[percentage weight_by_distance]
    }

    preferences.each do |attribute, units|
      units.each do |unit|
        user = users(:one).reload
        assert user.update(attribute => unit), user.errors.full_messages.join(", ")
      end

      [ nil, "", "unsupported" ].each do |value|
        user = users(:one).reload
        assert_not user.update(attribute => value)
        assert user.errors.of_kind?(attribute, :inclusion)
      end
    end
  end
end
