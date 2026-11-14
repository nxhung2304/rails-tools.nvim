# frozen_string_literal: true

class BaseApi < Grape::API
  prefix :api
  version 'v1', using: :path
  format :json

  mount V1::Users
  mount V1::Health
end
