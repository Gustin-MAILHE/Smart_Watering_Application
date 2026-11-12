class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :temperature_unit, :string, default: "celsius"
    add_column :users, :brightness_unit, :string, default: "percentage"
    add_column :users, :humidity_unit, :string, default: "percentage"
  end
end
