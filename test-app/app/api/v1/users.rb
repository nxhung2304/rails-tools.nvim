# frozen_string_literal: true

module V1
  class Users < Grape::API
    resource :users do
      desc 'List users'
      get do
        []
      end

      route_param :id do
        desc 'Show a user'
        get do
          {}
        end

        desc 'Deactivate a user'
        post :deactivate do
          {}
        end
      end
    end
  end
end
