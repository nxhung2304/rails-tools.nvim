# frozen_string_literal: true

class User < ApplicationRecord
  # Basic user model for testing rails-tools.nvim

  has_many :posts, dependent: :destroy
  has_one :profile, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(admin: true) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    admin == true
  end
end
