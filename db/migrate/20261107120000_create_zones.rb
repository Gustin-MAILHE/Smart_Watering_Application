class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, collation: "NOCASE"

      t.timestamps
    end

    add_index :zones, [ :user_id, :name ], unique: true
  end
end
