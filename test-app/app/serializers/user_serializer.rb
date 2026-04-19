# frozen_string_literal: true

class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :created_at

  has_many :posts
  has_one :profile

  def created_at
    object.created_at.iso8601
  end
end
