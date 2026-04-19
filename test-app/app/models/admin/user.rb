# frozen_string_literal: true

module Admin
  class User < ApplicationRecord
    # Admin namespace user model for testing nested navigation

    self.table_name = 'admin_users'

    has_many :managed_users, class_name: 'User', foreign_key: :admin_id

    validates :username, presence: true, uniqueness: true
    validates :permissions, presence: true

    def can_manage?(resource)
      permissions.include?(resource.to_s)
    end
  end
end
