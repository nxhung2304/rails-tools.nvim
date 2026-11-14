# frozen_string_literal: true

module V1
  class Health < Grape::API
    get :ping do
      { status: 'ok' }
    end
  end
end
