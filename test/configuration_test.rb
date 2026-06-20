# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @config = Plumbo::Configuration.new
  end

  # Defines a temporary top-level Rails constant for the block, then removes it,
  # so the Rails-host detection paths can be exercised in this plain-gem suite.
  def with_rails(root: nil, env: nil)
    fake = Module.new
    fake.define_singleton_method(:root) { root }
    fake.define_singleton_method(:env) { env } if env
    fake.define_singleton_method(:respond_to?) do |name, *|
      (name == :root) || (name == :env && !env.nil?) || super(name)
    end
    Object.const_set(:Rails, fake)
    yield
  ensure
    Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
  end

  def test_defaults
    refute @config.enabled
    assert_equal 500, @config.max_files
    assert_equal "@", @config.path_prefix
    assert @config.include_stimulus
    assert_equal "app/javascript", @config.javascript_root
  end

  def test_root_falls_back_to_cwd_without_rails
    assert_equal Dir.pwd, @config.root
  end

  def test_root_uses_rails_root_when_rails_is_present
    with_rails(root: "/rails/app") do
      assert_equal "/rails/app", Plumbo::Configuration.new.root
    end
  end

  def test_enabled_is_true_in_rails_development
    development = Object.new
    def development.development? = true

    with_rails(env: development) do
      assert Plumbo::Configuration.new.enabled
    end
  end
end
