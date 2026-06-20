# frozen_string_literal: true

# SimpleCov boot — installed by rails-cto
# Must run before the application is loaded so every `require`d file is tracked.
require "simplecov"
require "simplecov_json_formatter"

SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"

  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       SimpleCov::Formatter::JSONFormatter
                                                     ])
end

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "plumbo"
