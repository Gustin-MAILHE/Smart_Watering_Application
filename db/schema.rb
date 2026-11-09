# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_07_140000) do
  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "username", default: "", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "zones", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false, collation: "NOCASE"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "crop", default: "Carrots", null: false
    t.string "schedule", default: "Every 3 days - 8:00 PM", null: false
    t.float "humidity_threshold"
    t.float "temperature_threshold"
    t.float "brightness_threshold"
    t.boolean "configuration_saved", default: false, null: false
    t.index ["user_id", "name"], name: "index_zones_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_zones_on_user_id"
  end

  add_foreign_key "zones", "users"
end
