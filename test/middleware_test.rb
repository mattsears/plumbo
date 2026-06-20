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
    lambda do |_env|
      ActiveSupport::Notifications.instrument(
        "render_template.action_view", identifier: "/app/root/app/views/home.html.erb"
      ) { nil }
      [200, { "Content-Type" => content_type }, [body]]
    end
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

  # A downstream app that renders +identifier+ (a real file), then returns +body+.
  def app_rendering(identifier, body, content_type: "text/html")
    lambda do |_env|
      ActiveSupport::Notifications.instrument("render_template.action_view", identifier: identifier) { nil }
      [200, { "Content-Type" => content_type }, [body]]
    end
  end

  def test_nests_stimulus_controllers_under_the_view_that_references_them
    Dir.mktmpdir do |root|
      @config.root = root
      view = File.join(root, "app/views/home.html.erb")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, '<div data-controller="modal">hi</div>')

      app = app_rendering(view, "<html><body>hi</body></html>")
      _status, _headers, body = Plumbo::Middleware.new(app, @config).call({})
      html = body.join

      assert_includes html, "@app/views/home.html.erb"
      assert_includes html, "@app/javascript/controllers/modal_controller.js"
    end
  end

  def test_appends_stimulus_controllers_for_partials_rendered_via_turbo
    Dir.mktmpdir do |root|
      @config.root = root
      partial = File.join(root, "app/views/posts/_post.html.erb")
      FileUtils.mkdir_p(File.dirname(partial))
      File.write(partial, '<div data-controller="modal"></div>')

      app = app_rendering(partial, "<turbo-stream></turbo-stream>", content_type: "text/vnd.turbo-stream.html")
      _status, _headers, body = Plumbo::Middleware.new(app, @config).call({})
      html = body.join

      assert_includes html, '<turbo-stream action="plumbo-append" target="plumbo-list">'
      assert_includes html, "@app/javascript/controllers/modal_controller.js"
    end
  end

  def test_passes_through_non_html_responses
    json = [200, { "Content-Type" => "application/json" }, ['{"a":1}']]
    mw = Plumbo::Middleware.new(->(_env) { json }, @config)

    assert_equal json, mw.call({})
  end

  def test_appends_turbo_stream_update_to_turbo_stream_responses
    app = rendering_app("<turbo-stream></turbo-stream>", content_type: "text/vnd.turbo-stream.html")
    mw = Plumbo::Middleware.new(app, @config)
    _status, headers, body = mw.call({})
    html = body.join

    assert_includes html, '<turbo-stream action="plumbo-append" target="plumbo-list">'
    refute_includes html, 'id="plumbo"'
    assert_equal html.bytesize.to_s, headers["Content-Length"]
  end

  def test_appends_turbo_stream_update_to_turbo_frame_requests
    app = rendering_app("<turbo-frame id='x'>hi</turbo-frame>")
    mw = Plumbo::Middleware.new(app, @config)
    _status, _headers, body = mw.call({ "HTTP_TURBO_FRAME" => "x" })
    html = body.join

    assert_includes html, '<turbo-stream action="plumbo-append" target="plumbo-list">'
    refute_includes html, 'id="plumbo"'
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
    _status, _headers, body = mw.call({})

    refute_includes body.join, 'id="plumbo"'
  end
end
