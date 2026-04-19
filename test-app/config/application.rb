# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile
Bundler.require(*Rails.groups)

module TestApp
  class Application < Rails::Application
    # Initialize configuration defaults
    config.load_defaults 7.1

    # Configuration can be overridden in environment files
    # This is a minimal test app for rails-tools.nvim

    # Don't generate system test files
    config.generators.system_tests = nil

    # Use custom error pages
    config.exceptions_app = ->(env) { ErrorsController.action(:show) }

    # Auto-load lib and services
    config.autoload_paths << Rails.root.join('lib')
    config.autoload_paths << Rails.root.join('app/services')
  end
end
