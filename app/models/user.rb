class User < ApplicationRecord
  TEMPERATURE_UNITS = %w[celsius fahrenheit kelvin].freeze
  BRIGHTNESS_UNITS = %w[percentage lumen lux].freeze
  HUMIDITY_UNITS = %w[percentage weight_by_distance].freeze

  has_many :zones, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :temperature_unit, inclusion: { in: TEMPERATURE_UNITS }
  validates :brightness_unit, inclusion: { in: BRIGHTNESS_UNITS }
  validates :humidity_unit, inclusion: { in: HUMIDITY_UNITS }
end
