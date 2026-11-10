class Zone < ApplicationRecord
  CROPS = %w[Tomatoes Lettuce Carrots Strawberries].freeze
  SCHEDULES = [ "Every 2 days - 6:00 AM", "Every day - 7:00 AM", "Every 3 days - 8:00 PM" ].freeze
  CONFIGURATION_FIELDS = %w[crop schedule watering_time_slots watering_starts_on watering_ends_on humidity_threshold temperature_threshold brightness_threshold].freeze
  WATERING_TIME = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :user

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 60 },
    uniqueness: { scope: :user_id, case_sensitive: false }
  validates :crop, inclusion: { in: CROPS }
  validates :schedule, inclusion: { in: SCHEDULES }
  validate :validate_watering_time_slots
  validate :validate_watering_dates
  validates :humidity_threshold, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :temperature_threshold, numericality: { greater_than_or_equal_to: -50, less_than_or_equal_to: 100 }, allow_nil: true
  validates :brightness_threshold, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 200_000 }, allow_nil: true

  before_save :mark_configuration_saved

  def thresholds
    { humidity: humidity_threshold, temperature: temperature_threshold, brightness: brightness_threshold }
  end

  def thresholds=(values)
    self.configuration_saved = true
    values.to_h.each do |key, value|
      public_send("#{key}_threshold=", value) if %w[humidity temperature brightness].include?(key.to_s)
    end
  end

  def garden_data
    { id: id, name: name, crop: crop, schedule: schedule, thresholds: thresholds,
      watering_time_slots: watering_time_slots, watering_starts_on: watering_starts_on&.iso8601,
      watering_ends_on: watering_ends_on&.iso8601,
      configurationSaved: configuration_saved }
  end

  private

  def validate_watering_time_slots
    slots = watering_time_slots
    unless slots.is_a?(Array) && slots.length.between?(1, 24) && slots.all? { |slot|
      slot.is_a?(Hash) && slot.keys.sort == %w[end start] &&
        slot.values.all? { |value| value.is_a?(String) && WATERING_TIME.match?(value) } && slot["start"] < slot["end"]
    }
      errors.add(:watering_time_slots, "doivent contenir de 1 à 24 créneaux valides, avec une fin après le début le même jour")
      return
    end

    if slots.sort_by { |slot| slot["start"] }.each_cons(2).any? { |first, second| first["end"] > second["start"] }
      errors.add(:watering_time_slots, "ne doivent pas se chevaucher")
    end
  end

  def validate_watering_dates
    %w[watering_starts_on watering_ends_on].each do |field|
      raw = public_send("#{field}_before_type_cast")
      next if raw.blank?

      begin
        unless raw.is_a?(Date)
          raise Date::Error unless raw.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(raw)
        end
        date = raw.is_a?(Date) ? raw : Date.iso8601(raw)
        raise Date::Error unless date.year.between?(1, 9999)
      rescue Date::Error
        errors.add(field, :invalid)
      end
    end
    if watering_starts_on && watering_ends_on && watering_ends_on < watering_starts_on
      errors.add(:watering_ends_on, "doit être le même jour ou après la date de début")
    end
  end

  def mark_configuration_saved
    self.configuration_saved = true if new_record? || CONFIGURATION_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
  end
end
