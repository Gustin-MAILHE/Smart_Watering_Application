class Zone < ApplicationRecord
  CROPS = %w[Tomatoes Lettuce Carrots Strawberries].freeze
  SCHEDULES = [ "Every 2 days - 6:00 AM", "Every day - 7:00 AM", "Every 3 days - 8:00 PM" ].freeze
  CONFIGURATION_FIELDS = %w[crop schedule humidity_threshold temperature_threshold brightness_threshold].freeze

  belongs_to :user

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 60 },
    uniqueness: { scope: :user_id, case_sensitive: false }
  validates :crop, inclusion: { in: CROPS }
  validates :schedule, inclusion: { in: SCHEDULES }
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
      configurationSaved: configuration_saved }
  end

  private

  def mark_configuration_saved
    self.configuration_saved = true if new_record? || CONFIGURATION_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
  end
end
