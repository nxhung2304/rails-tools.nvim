# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.references :admin_user, foreign_key: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    create_table :admin_users do |t|
      t.string :username
    end
  end
end
