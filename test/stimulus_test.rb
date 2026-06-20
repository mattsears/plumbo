# frozen_string_literal: true

require "test_helper"

class StimulusTest < Minitest::Test
  def setup
    @config = Plumbo::Configuration.new
  end

  def controllers(html)
    Plumbo::Stimulus.controllers(html, @config)
  end

  def test_maps_a_simple_identifier_to_its_controller_file
    html = '<div data-controller="hello">'

    assert_equal ["@app/javascript/controllers/hello_controller.js"], controllers(html)
  end

  def test_maps_multiple_identifiers_in_one_attribute
    html = '<div data-controller="hello modal">'

    assert_equal [
      "@app/javascript/controllers/hello_controller.js",
      "@app/javascript/controllers/modal_controller.js"
    ], controllers(html)
  end

  def test_dashed_identifier_becomes_underscored_file
    html = '<div data-controller="date-picker">'

    assert_equal ["@app/javascript/controllers/date_picker_controller.js"], controllers(html)
  end

  def test_namespaced_identifier_becomes_nested_path
    html = '<div data-controller="users--list-item">'

    assert_equal ["@app/javascript/controllers/users/list_item_controller.js"], controllers(html)
  end

  def test_dedupes_repeated_controllers
    html = '<div data-controller="hello"></div><span data-controller="hello"></span>'

    assert_equal ["@app/javascript/controllers/hello_controller.js"], controllers(html)
  end

  def test_handles_single_quoted_attributes
    html = "<div data-controller='hello'>"

    assert_equal ["@app/javascript/controllers/hello_controller.js"], controllers(html)
  end

  def test_blank_path_prefix_yields_bare_paths
    @config.path_prefix = ""

    assert_equal ["app/javascript/controllers/hello_controller.js"], controllers('<div data-controller="hello">')
  end

  def test_respects_custom_javascript_root
    @config.javascript_root = "frontend"

    assert_equal ["@frontend/controllers/hello_controller.js"], controllers('<div data-controller="hello">')
  end

  def test_returns_empty_when_disabled
    @config.include_stimulus = false

    assert_empty controllers('<div data-controller="hello">')
  end

  def test_returns_empty_when_no_controllers_present
    assert_empty controllers("<div>nothing here</div>")
  end

  # Writes +contents+ to +relative+ under a temp root and points the config there.
  def with_view(relative, contents)
    Dir.mktmpdir do |root|
      @config.root = root
      path = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
      yield
    end
  end

  def test_nest_inserts_controllers_under_the_referencing_view
    with_view("app/views/posts/_post.html.erb", '<div data-controller="modal">') do
      nested = Plumbo::Stimulus.nest([["@app/views/posts/_post.html.erb", 1]], @config)

      assert_equal [
        ["@app/views/posts/_post.html.erb", 1],
        ["@app/javascript/controllers/modal_controller.js", 2]
      ], nested
    end
  end

  def test_nest_ignores_non_erb_and_missing_files
    @config.root = "/nope"
    files = [["@app/controllers/posts_controller.rb", 0], ["@app/views/x.html.erb", 0]]

    assert_equal files, Plumbo::Stimulus.nest(files, @config)
  end

  def test_nest_returns_input_when_disabled
    @config.include_stimulus = false
    files = [["@app/views/x.html.erb", 0]]

    assert_equal files, Plumbo::Stimulus.nest(files, @config)
  end
end
