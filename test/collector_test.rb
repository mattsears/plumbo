# frozen_string_literal: true

require "test_helper"

class CollectorTest < Minitest::Test
  def setup
    @config = Plumbo::Configuration.new
    @config.enabled = true
    @config.root = "/app/root"
  end

  def instrument(event, payload)
    ActiveSupport::Notifications.instrument(event, payload) { nil }
  end

  def test_collects_render_files_relative_and_prefixed
    collector = Plumbo::Collector.new(@config)
    collector.collect do
      instrument("render_template.action_view", identifier: "/app/root/app/views/posts/show.html.erb")
      instrument("render_partial.action_view", identifier: "/app/root/app/views/posts/_post.html.erb")
    end

    assert_equal [
      ["@app/views/posts/show.html.erb", 0],
      ["@app/views/posts/_post.html.erb", 0]
    ], collector.files
  end

  def test_orders_renders_by_when_they_start_not_when_they_finish
    collector = Plumbo::Collector.new(@config)
    collector.collect do
      # A template that renders a partial: the partial's event fires first (it
      # finishes first), but the template started first, so it must rank first.
      ActiveSupport::Notifications.instrument(
        "render_template.action_view", identifier: "/app/root/app/views/posts/index.html.erb"
      ) do
        instrument("render_partial.action_view", identifier: "/app/root/app/views/posts/_header.html.erb")
      end
    end

    # The template is at depth 0; the partial it renders is nested at depth 1.
    assert_equal [
      ["@app/views/posts/index.html.erb", 0],
      ["@app/views/posts/_header.html.erb", 1]
    ], collector.files
  end

  def test_ignores_files_outside_the_app_root
    collector = Plumbo::Collector.new(@config)
    collector.collect do
      instrument("render_template.action_view", identifier: "/gem/path/views/thing.html.erb")
    end

    assert_empty collector.files
  end

  def test_dedupes_repeated_renders
    collector = Plumbo::Collector.new(@config)
    collector.collect do
      instrument("render_partial.action_view", identifier: "/app/root/app/views/x/_a.html.erb")
      instrument("render_partial.action_view", identifier: "/app/root/app/views/x/_a.html.erb")
    end

    assert_equal [["@app/views/x/_a.html.erb", 0]], collector.files
  end

  def test_respects_max_files
    @config.max_files = 1
    collector = Plumbo::Collector.new(@config)
    collector.collect do
      instrument("render_partial.action_view", identifier: "/app/root/app/views/x/_a.html.erb")
      instrument("render_partial.action_view", identifier: "/app/root/app/views/x/_b.html.erb")
    end

    assert_equal 1, collector.files.size
  end

  def test_blank_path_prefix_yields_bare_paths
    @config.path_prefix = ""
    collector = Plumbo::Collector.new(@config)
    collector.collect do
      instrument("render_template.action_view", identifier: "/app/root/app/views/y/z.html.erb")
    end

    assert_equal [["app/views/y/z.html.erb", 0]], collector.files
  end

  def test_prepends_controller_and_helper_when_files_exist
    Dir.mktmpdir do |root|
      @config.root = root
      FileUtils.mkdir_p(File.join(root, "app/controllers/admin/ai"))
      FileUtils.mkdir_p(File.join(root, "app/helpers/admin/ai"))
      File.write(File.join(root, "app/controllers/admin/ai/agents_controller.rb"), "")
      File.write(File.join(root, "app/helpers/admin/ai/agents_helper.rb"), "")

      collector = Plumbo::Collector.new(@config)
      collector.collect do
        instrument("render_template.action_view",
                   identifier: File.join(root, "app/views/admin/ai/agents/index.html.erb"))
        instrument("process_action.action_controller", controller: "Admin::Ai::AgentsController")
      end

      assert_equal [
        ["@app/controllers/admin/ai/agents_controller.rb", 0],
        ["@app/helpers/admin/ai/agents_helper.rb", 0],
        ["@app/views/admin/ai/agents/index.html.erb", 0]
      ], collector.files
    end
  end

  def test_skips_controller_helper_files_that_do_not_exist
    Dir.mktmpdir do |root|
      @config.root = root
      collector = Plumbo::Collector.new(@config)
      collector.collect do
        instrument("process_action.action_controller", controller: "MissingController")
      end

      assert_empty collector.files
    end
  end
end
