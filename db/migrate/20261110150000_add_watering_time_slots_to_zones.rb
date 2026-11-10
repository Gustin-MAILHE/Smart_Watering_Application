class AddWateringTimeSlotsToZones < ActiveRecord::Migration[8.1]
  def up
    add_column :zones, :watering_time_slots, :json, null: false, default: [ { start: "20:00", end: "20:30" } ]
    add_column :zones, :watering_starts_on, :date
    add_column :zones, :watering_ends_on, :date

    execute <<~SQL
      UPDATE zones SET watering_time_slots = CASE schedule
        WHEN 'Every 2 days - 6:00 AM' THEN '[{"start":"06:00","end":"06:30"}]'
        WHEN 'Every day - 7:00 AM' THEN '[{"start":"07:00","end":"07:30"}]'
        ELSE '[{"start":"20:00","end":"20:30"}]'
      END
    SQL
  end

  def down
    remove_column :zones, :watering_time_slots
    remove_column :zones, :watering_starts_on
    remove_column :zones, :watering_ends_on
  end
end
