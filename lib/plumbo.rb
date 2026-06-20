# frozen_string_literal: true

require "plumbo/version"
require "plumbo/configuration"
require "plumbo/collector"
require "plumbo/stimulus"
require "plumbo/panel"
require "plumbo/middleware"

# Plumbo — a development-only panel that lists every controller, view, and
# partial used to render the current page, with click-to-copy @paths for
# pasting into an AI assistant. Self-contained: it injects its own HTML, CSS,
# and JS, so the host app needs no Tailwind, Stimulus, or JS bundler.
module Plumbo
  class << self
    # Global configuration, lazily created with dev-only defaults.
    def config
      @config ||= Configuration.new
    end

    # Override defaults from an initializer: Plumbo.configure { |c| ... }
    def configure
      yield config
    end

    # Exposed mainly so tests can swap in a fresh configuration.
    attr_writer :config
  end
end

require "plumbo/railtie" if defined?(Rails::Railtie)
