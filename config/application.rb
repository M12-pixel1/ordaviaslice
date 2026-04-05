# frozen_string_literal: true

require_relative "boot"
require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Ordaviaslice
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.api_only = false
  end
end
