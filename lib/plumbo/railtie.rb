# frozen_string_literal: true

require "rails/railtie"

module Plumbo
  # Wires the middleware into the Rack stack. It's inserted unconditionally; the
  # per-request `config.enabled` gate (development by default) makes it a no-op
  # elsewhere and lets a host toggle it from an initializer.
  class Railtie < Rails::Railtie
    initializer "plumbo.middleware" do |app|
      app.middleware.use Plumbo::Middleware
    end
  end
end
