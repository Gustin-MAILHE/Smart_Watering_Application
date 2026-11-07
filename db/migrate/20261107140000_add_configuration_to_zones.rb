class AddConfigurationToZones < ActiveRecord::Migration[8.1]
  def change
    add_column :zones, :crop, :string, null: false, default: "Carrots"
    add_column :zones, :schedule, :string, null: false, default: "Every 3 days - 8:00 PM"
    add_column :zones, :humidity_threshold, :float
    add_column :zones, :temperature_threshold, :float
    add_column :zones, :brightness_threshold, :float
    add_column :zones, :configuration_saved, :boolean, null: false, default: false
  end
end
