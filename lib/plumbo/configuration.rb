# frozen_string_literal: true

module Plumbo
  # Runtime configuration for the panel. Defaults are dev-only and safe; override
  # in an initializer via Plumbo.configure { |c| ... }.
  class Configuration
    # Whether the panel is injected. Defaults to true only in Rails development.
    attr_accessor :enabled

    # Hard cap on the number of files listed (guards against runaway pages).
    attr_accessor :max_files

    # Prefix added to each listed path. "@" makes the list paste-ready as file
    # mentions for an AI assistant; set to "" for bare paths.
    attr_accessor :path_prefix

    # Whether to list Stimulus controllers found via data-controller attributes
    # in the rendered HTML. Defaults to true.
    attr_accessor :include_stimulus

    # Source directory Stimulus controllers are mapped into. Combined with the
    # "controllers/" subdirectory and the Stimulus identifier to form the path.
    attr_accessor :javascript_root

    attr_writer :root

    def initialize
      @enabled = rails_development?
      @max_files = 500
      @path_prefix = "@"
      @include_stimulus = true
      @javascript_root = "app/javascript"
      @root = nil
    end

    # Project root, used to (a) filter render events down to app files and
    # (b) make listed paths relative. Defaults to Rails.root, then the cwd.
    def root
      @root ||= rails_root || Dir.pwd
    end

    private

    def rails_development?
      defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
    end

    def rails_root
      return unless defined?(Rails) && Rails.respond_to?(:root)

      root = Rails.root
      root&.to_s
    end
  end
end
