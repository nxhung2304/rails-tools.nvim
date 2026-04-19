# frozen_string_literal: true

Rails.application.routes.draw do
  # Root route
  root 'users#index'

  # User resources
  resources :users, only: %i[index show new create edit update destroy] do
    member do
      post :deactivate
      post :promote
    end
  end

  # Admin namespace
  namespace :admin do
    resources :users, only: %i[index show update]
    resources :settings, only: %i[index update]
  end

  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }

  # API routes (for Grape testing later)
  # API versioning will be handled in Grape API mount
end
