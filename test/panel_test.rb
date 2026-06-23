# frozen_string_literal: true

require "test_helper"

class PanelTest < Minitest::Test
  def test_renders_wrapper_styles_script_and_files
    html = Plumbo::Panel.render(
      ["@app/controllers/posts_controller.rb", "@app/views/posts/show.html.erb"]
    )

    assert_includes html, 'id="plumbo"'
    assert_includes html, "<style>"
    assert_includes html, "<script>"
    assert_includes html, "Plumbo ("
    assert_includes html, '<span class="plumbo-count">2</span>'
    assert_includes html, "@app/controllers/posts_controller.rb"
    assert_includes html, "@app/views/posts/show.html.erb"
  end

  def test_renders_copy_all_and_clear_all_controls
    html = Plumbo::Panel.render(["@app/views/posts/show.html.erb"])

    assert_includes html, "data-plumbo-copy-all"
    assert_includes html, "data-plumbo-clear"
    assert_includes html, 'title="Clear the list to watch new files as you navigate"'
  end

  def test_renders_filter_bar
    html = Plumbo::Panel.render(["@app/views/posts/show.html.erb"])

    assert_includes html, "data-plumbo-filter"
    assert_includes html, "data-plumbo-chips"
  end

  def test_indents_and_tags_nested_rows_by_depth
    html = Plumbo::Panel.render([
                                  ["@app/views/posts/index.html.erb", 0],
                                  ["@app/views/posts/_post.html.erb", 1]
                                ])

    assert_includes html, 'data-depth="0"'
    assert_includes html, 'data-depth="1"'
    assert_includes html, "--d:1"
  end

  def test_rows_no_longer_show_index_numbers
    html = Plumbo::Panel.render(["@app/views/posts/show.html.erb"])

    refute_includes html, "plumbo-index"
  end

  def test_rows_include_a_collapse_caret
    html = Plumbo::Panel.render(["@app/views/posts/index.html.erb"])

    assert_includes html, 'class="plumbo-caret"'
  end

  def test_row_toggles_collapse_and_copy_lives_on_the_icon
    html = Plumbo::Panel.render(["@app/views/posts/index.html.erb"])

    assert_includes html, 'class="plumbo-row" data-plumbo-collapse'
    assert_includes html, 'class="plumbo-copy" data-plumbo-copy'
  end

  def test_rows_carry_their_category_for_filtering
    html = Plumbo::Panel.render(
      ["@app/controllers/posts_controller.rb", "@app/javascript/controllers/hello_controller.js"]
    )

    assert_includes html, 'data-category="controller"'
    assert_includes html, 'data-category="javascript"'
  end

  def test_escapes_paths
    html = Plumbo::Panel.render(['@app/views/x"<>.erb'])

    refute_includes html, '"<>.erb'
    assert_includes html, "&lt;"
    assert_includes html, "&gt;"
  end

  def test_renders_a_type_icon_for_each_row
    html = Plumbo::Panel.render(["@app/controllers/posts_controller.rb"])

    assert_includes html, 'class="plumbo-type"'
  end

  def test_categorizes_files_by_path
    assert_equal :controller, Plumbo::Panel.category("@app/controllers/posts_controller.rb")
    assert_equal :helper, Plumbo::Panel.category("@app/helpers/posts_helper.rb")
    assert_equal :partial, Plumbo::Panel.category("@app/views/layouts/_sidebar.html.erb")
    assert_equal :layout, Plumbo::Panel.category("@app/views/layouts/application.html.erb")
    assert_equal :view, Plumbo::Panel.category("@app/views/posts/index.html.erb")
    assert_equal :javascript, Plumbo::Panel.category("@app/javascript/controllers/hello_controller.js")
    assert_equal :ruby, Plumbo::Panel.category("@app/models/post.rb")
    assert_equal :file, Plumbo::Panel.category("@config/routes.txt")
  end

  def test_distinct_icons_for_different_types
    controller = Plumbo::Panel.file_icon("@app/controllers/posts_controller.rb")
    view = Plumbo::Panel.file_icon("@app/views/posts/index.html.erb")

    refute_equal controller, view
  end
end
