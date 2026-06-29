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

    # Enable Rails' filename annotations so each rendered template/partial is
    # wrapped in BEGIN/END HTML comments — the markers the panel's hover-to-
    # highlight reads to map a row back to its region on the page. Templates bake
    # the comments in at compile time, so this must be set before Action View is
    # configured rather than per-request. Only ever switched on (never off) so a
    # host that enabled it independently keeps it.
    initializer "plumbo.annotate_views", before: "action_view.setup" do |app|
      config = Plumbo.config
      app.config.action_view.annotate_rendered_view_with_filenames = true if config.enabled && config.highlight
    end
  end
end
