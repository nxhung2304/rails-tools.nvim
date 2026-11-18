# frozen_string_literal: true

ActiveRecord::Schema[7.1].define(version: 2024_02_01_000000) do
  create_table "admin_users", force: :cascade do |t|
    t.string "username"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.integer "admin_user_id"
    t.timestamps
  end
end
