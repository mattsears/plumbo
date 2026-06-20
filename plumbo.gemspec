# frozen_string_literal: true

require_relative "lib/plumbo/version"

Gem::Specification.new do |spec|
  spec.name = "plumbo"
  spec.version = Plumbo::VERSION
  spec.authors = ["Matt Sears"]
  spec.email = ["matt@mattsears.com"]

  spec.summary = "A zero-config dev panel listing every controller, view, and partial behind the current page."
  spec.description = "Plumbo injects a development-only panel into your Rails app that traces every file " \
    "(controller, helper, layout, templates, partials) used to render the current page, with click-to-copy " \
    "@paths for pasting into an AI assistant. Self-contained: no Tailwind, Stimulus, or JS bundler required."
  spec.homepage = "https://github.com/mattsears/plumbo"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE.txt"].select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 6.1"
  spec.add_dependency "rack", ">= 2.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
