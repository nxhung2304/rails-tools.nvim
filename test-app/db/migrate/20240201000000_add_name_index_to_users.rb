# frozen_string_literal: true

class AddNameIndexToUsers < ActiveRecord::Migration[7.1]
  def change
    add_index :users, :name
  end
end
