module ApplicationHelper

  # These values are for reference only; they depend on the equipment used and the environment.
  MAX_LUX = 100_000
  MAX_LUMENS = 2_000

  # return the chosen temperature unit
  def temperature_symbol(user)
    case user&.temperature_unit
    when 'fahrenheit' then '°F'
    when 'kelvin' then 'K'
    else '°C'
    end
  end

  # conversion
  def display_temperature(celsius_value, user)
    return "-" unless celsius_value.present?

    converted_value = case user&.temperature_unit
                      when 'fahrenheit' then (celsius_value * 9 / 5) + 32
                      when 'kelvin' then celsius_value + 273.15
                      else celsius_value
                      end

    converted_value.round(1) # rounds to 1 decimal place
  end

  def brightness_symbol(user)
    case user&.brightness_unit
    when 'lumen' then 'lm'
    when 'lux' then 'lx'
    else '%'
    end
  end

  def display_brightness(percentage_value, user)
    return "-" unless percentage_value.present?

    converted_value = case user&.brightness_unit
                      when 'lux' then (percentage_value / 100) * MAX_LUX
                      when 'lumen' then (percentage_value / 100) * MAX_LUMENS
                      else percentage_value
                      end

    converted_value.round(0)
  end

  def humidity_symbol(user)
    case user&.humidity_unit
    when 'weight-by-distance', 'weight_by_distance' then 'g/m³'
    else '%'
    end
  end

  def display_humidity(humidity_percentage, temp_celsius, user)
    return "-" unless humidity_percentage.present?

    case user&.humidity_unit
    when 'weight-by-distance', 'weight_by_distance'
      return "-" unless temp_celsius.present?

      temp_k = temp_celsius + 273.15 # physical formula for absolute humidity (g/m³)

      # Calculation of the actual vapor pressure (in hecto Pascal (hPa))
      vapor_pressure = 6.112 * Math.exp(((17.67 * temp_celsius) / (temp_celsius + 243.5)).to_f) * (humidity_percentage / 100)

      # Conversion to g/m³
      absolute_humidity = (vapor_pressure * 216.7) / temp_k
      absolute_humidity.round(1)
    else
      humidity_percentage.round(0)
    end
  end

end
