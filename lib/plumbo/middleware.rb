# frozen_string_literal: true

module Plumbo
  # Rack middleware that, when enabled (development by default), watches a
  # request's render events and adds the Plumbo panel to the response.
  #
  # For full HTML pages the panel is injected before </body>. For Turbo Stream
  # and Turbo Frame responses — which render controllers/views but never reload
  # the page — it instead appends <turbo-stream> actions that refresh the panel
  # already on the page, so the file list keeps up with Turbo navigations.
  # (Turbo Drive visits need no special handling: they swap <body>, which brings
  # a freshly injected panel.) Other responses and requests that rendered
  # nothing pass through untouched. The how-and-whether of rewriting lives in
  # Injection so the response-shape checks read request state instead of being
  # passed around.
  class Middleware
    def initialize(app, config = nil)
      @app = app
      @config = config
    end

    # :reek:DuplicateMethodCall — the disabled passthrough and the instrumented
    # path are intentionally distinct calls into the downstream app.
    def call(env)
      return @app.call(env) unless config.enabled

      collector = Collector.new(config)
      status, headers, response = collector.collect { @app.call(env) }

      injection = Injection.new(env, headers, collector.files, config)
      return [status, headers, response] unless injection.applicable?

      body = injection.rewrite(response)
      headers["Content-Length"] = body.bytesize.to_s
      [status, headers, [body]]
    end

    private

    # Read at call time so host config set in an initializer is honored.
    def config
      @config || Plumbo.config
    end

    # Decides whether and how to add the panel to a single response, holding the
    # per-request env/headers/files so its checks read instance state.
    class Injection
      def initialize(env, headers, files, config)
        @env = env
        @headers = headers
        @files = files
        @config = config
      end

      # True when something rendered and this response can carry the panel.
      def applicable?
        @files.any? && (turbo? || html?)
      end

      # The rewritten body string. The render files are augmented with any
      # Stimulus controllers found in this body. Turbo responses get appended
      # stream updates; full HTML pages get the panel injected before </body>.
      # :reek:ManualDispatch — Rack bodies only optionally respond to #close.
      # :reek:FeatureEnvy — assembling the response body operates on the buffer.
      def rewrite(response)
        body = +""
        response.each { |part| body << part }
        response.close if response.respond_to?(:close)

        files = panel_files
        return body + Panel.turbo_update(files) if turbo?

        marker = body.rindex("</body>")
        marker ? body.dup.insert(marker, Panel.render(files)) : body
      end

      private

      # The render files with each template/partial's Stimulus controllers nested
      # underneath, deduped by path (first occurrence wins) and capped.
      def panel_files
        Stimulus.nest(@files, @config).uniq { |path, _depth| path }.first(@config.max_files)
      end

      def turbo?
        turbo_stream? || turbo_frame?
      end

      def html?
        content_type&.include?("text/html")
      end

      def turbo_stream?
        content_type&.include?("turbo-stream")
      end

      # Turbo sends this request header on frame navigations.
      def turbo_frame?
        !@env["HTTP_TURBO_FRAME"].to_s.empty?
      end

      def content_type
        @headers["Content-Type"] || @headers["content-type"]
      end
    end
  end
end
