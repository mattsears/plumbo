# frozen_string_literal: true

require "test_helper"

class MiddlewareTest < Minitest::Test
  def setup
    @config = Plumbo::Configuration.new
    @config.enabled = true
    @config.root = "/app/root"
  end

  # A downstream app that renders one in-root template, then returns +body+.
  def rendering_app(body, content_type: "text/html")
    app_rendering("/app/root/app/views/home.html.erb", body, content_type: content_type)
  end

  # A downstream app that renders +identifier+, then returns +body+.
  def app_rendering(identifier, body, content_type: "text/html")
    lambda do |_env|
      ActiveSupport::Notifications.instrument("render_template.action_view", identifier: identifier) { nil }
      [200, { "Content-Type" => content_type }, [body]]
    end
  end

  # The decoded X-Plumbo-Files header as an array of [path, depth, category].
  def files_header(headers)
    JSON.parse(headers["X-Plumbo-Files"].unpack1("m0"))
  end

  def test_injects_panel_before_closing_body
    mw = Plumbo::Middleware.new(rendering_app("<html><body>hi</body></html>"), @config)
    status, headers, body = mw.call({})
    html = body.join

    assert_equal 200, status
    assert_includes html, 'id="plumbo"'
    assert_operator html.index('id="plumbo"'), :<, html.index("</body>")
    assert_equal html.bytesize.to_s, headers["Content-Length"]
  end

  def test_sets_the_files_header_listing_rendered_files
    mw = Plumbo::Middleware.new(rendering_app("<html><body>hi</body></html>"), @config)
    _status, headers, _body = mw.call({})

    assert_equal [["@app/views/home.html.erb", 0, "view"]], files_header(headers)
  end

  def test_sets_the_header_without_injecting_for_frame_fragments
    app = rendering_app("<turbo-frame id='x'>hi</turbo-frame>")
    mw = Plumbo::Middleware.new(app, @config)
    _status, headers, body = mw.call({ "HTTP_TURBO_FRAME" => "x" })

    refute_includes body.join, 'id="plumbo"'
    assert_includes files_header(headers).map(&:first), "@app/views/home.html.erb"
  end

  def test_sets_the_header_for_turbo_stream_responses
    app = rendering_app("<turbo-stream></turbo-stream>", content_type: "text/vnd.turbo-stream.html")
    mw = Plumbo::Middleware.new(app, @config)
    _status, headers, body = mw.call({})

    assert_equal "<turbo-stream></turbo-stream>", body.join
    assert_includes files_header(headers).map(&:first), "@app/views/home.html.erb"
  end

  def test_header_nests_stimulus_controllers_under_the_referencing_view
    Dir.mktmpdir do |root|
      @config.root = root
      partial = File.join(root, "app/views/posts/_post.html.erb")
      FileUtils.mkdir_p(File.dirname(partial))
      File.write(partial, '<div data-controller="modal"></div>')

      app = app_rendering(partial, "<turbo-frame id='x'>hi</turbo-frame>")
      _status, headers, _body = Plumbo::Middleware.new(app, @config).call({ "HTTP_TURBO_FRAME" => "x" })

      assert_includes files_header(headers), ["@app/javascript/controllers/modal_controller.js", 1, "javascript"]
    end
  end

  def test_passes_through_non_html_responses
    json = [200, { "Content-Type" => "application/json" }, ['{"a":1}']]
    mw = Plumbo::Middleware.new(->(_env) { json }, @config)

    assert_equal json, mw.call({})
  end

  def test_passes_through_when_disabled
    @config.enabled = false
    original = [200, { "Content-Type" => "text/html" }, ["<body></body>"]]
    mw = Plumbo::Middleware.new(->(_env) { original }, @config)

    assert_same original, mw.call({})
  end

  def test_passes_through_when_nothing_rendered
    plain = ->(_env) { [200, { "Content-Type" => "text/html" }, ["<html><body>hi</body></html>"]] }
    mw = Plumbo::Middleware.new(plain, @config)
    _status, headers, body = mw.call({})

    refute_includes body.join, 'id="plumbo"'
    assert_nil headers["X-Plumbo-Files"]
  end
end
