# frozen_string_literal: true

require "json"

module Plumbo
  # Rack middleware that, when enabled (development by default), watches a
  # request's render events and adds the Plumbo panel to the response.
  #
  # Every response that rendered app files carries an X-Plumbo-Files header (the
  # file list, with Stimulus controllers nested in). Full HTML pages also get the
  # panel injected before </body> for the initial render. The client reads the
  # header on every fetch — so Turbo Drive, Frame, and Stream navigations, and
  # even custom fetch-based panes, all refresh the panel without a full reload.
  # Requests that rendered nothing pass through untouched. Whether/how to rewrite
  # the body lives in Injection so its checks read request state.
  class Middleware
    HEADER = "X-Plumbo-Files"

    def initialize(app, config = nil)
      @app = app
      @config = config
    end

    # :reek:DuplicateMethodCall — the disabled passthrough and the instrumented
    # path are intentionally distinct calls into the downstream app.
    def call(env)
      return @app.call(env) unless config.enabled

      collector = Collector.new(config)
      triple = collector.collect { @app.call(env) }
      Injection.new(triple, panel_files(collector.files)).apply
    end

    private

    # Read at call time so host config set in an initializer is honored.
    def config
      @config || Plumbo.config
    end

    # The render files with each template/partial's Stimulus controllers nested
    # underneath, deduped by path (first occurrence wins) and capped.
    def panel_files(files)
      conf = config
      Stimulus.nest(files, conf).uniq { |path, _depth| path }.first(conf.max_files)
    end

    # Adds the panel to a single response: an X-Plumbo-Files header on anything
    # with files, plus the injected panel markup for full HTML pages. Holds the
    # response triple and files as instance state.
    class Injection
      def initialize(triple, files)
        @status, @headers, @response = triple
        @files = files
      end

      # The final Rack triple, with the header and (for full HTML) the panel.
      def apply
        passthrough = [@status, @headers, @response]
        return passthrough if @files.empty?

        @headers[HEADER] = header_value
        return passthrough unless html?

        body = rewrite
        @headers["Content-Length"] = body.bytesize.to_s
        [@status, @headers, [body]]
      end

      private

      # The file list as compact Base64-encoded JSON ([path, depth, category]
      # triples) for the X-Plumbo-Files header the client reads to refresh.
      def header_value
        data = @files.map { |path, depth| [path, depth, Panel.category(path)] }
        [JSON.generate(data)].pack("m0")
      end

      def html?
        content_type.include?("text/html")
      end

      # The body with the panel injected before </body>, or unchanged when there
      # is no </body> (e.g. a Turbo Frame fragment — the client still refreshes
      # from the header).
      # :reek:ManualDispatch — Rack bodies only optionally respond to #close.
      # :reek:FeatureEnvy — assembling the response body operates on the buffer.
      def rewrite
        body = +""
        @response.each { |part| body << part }
        @response.close if @response.respond_to?(:close)

        marker = body.rindex("</body>")
        marker ? body.dup.insert(marker, Panel.render(@files)) : body
      end

      def content_type
        (@headers["Content-Type"] || @headers["content-type"]).to_s
      end
    end
  end
end
