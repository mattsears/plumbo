# frozen_string_literal: true

require "active_support/isolated_execution_state"
require "active_support/notifications"
require "active_support/core_ext/string/inflections"

module Plumbo
  # Subscribes to ActionView/ActionController notifications for the duration of a
  # single request and gathers every project file that took part in rendering.
  # Render events are recorded with the timestamp at which each render began, so
  # #files can return them in true call order (a template before the partials it
  # renders) rather than the inner-to-outer order in which the events fire on
  # completion. Subscriptions are scoped to the calling thread so concurrent
  # requests on a threaded dev server don't bleed into one another.
  class Collector
    RENDER_EVENTS = %w[
      render_template.action_view
      render_partial.action_view
      render_layout.action_view
    ].freeze

    CONTROLLER_EVENT = "process_action.action_controller"

    def initialize(config = Plumbo.config)
      @config = config
      @leading = []   # controller + helper, forced to the top of the list
      @renders = []   # [start_time, prefixed_path] for each template/partial
      @root_prefix = File.join(@config.root, "")
    end

    # Runs the block with subscriptions active and returns whatever it returns
    # (the downstream Rack response triple). Render and controller events go to
    # separate handlers so neither has to branch on the event name.
    def collect(&block)
      @thread = Thread.current
      with_subscriptions(RENDER_EVENTS, method(:on_render)) do
        with_subscriptions([CONTROLLER_EVENT], method(:on_controller), &block)
      end
    end

    # Project files as [path, depth] pairs in call order: controller and helper
    # first (depth 0), then every template/partial sorted by when its render
    # began, so a template precedes the partials it renders. Each render's depth
    # is how many other renders enclose it, giving a parent/child nesting.
    # Deduped by path (first occurrence wins) and capped at max_files.
    def files
      entries = leading_entries + render_entries
      entries.uniq { |path, _depth| path }.first(@config.max_files)
    end

    private

    def leading_entries
      @leading.map { |path| [path, 0] }
    end

    # Renders in call order (by start time), each tagged with its nesting depth.
    def render_entries
      @renders.sort_by { |start, _finish, _path| start }
              .map { |start, finish, path| [path, depth_of(start, finish)] }
    end

    # Depth is the number of other render intervals that strictly enclose this
    # one — renders nest cleanly because view rendering is synchronous.
    # :reek:FeatureEnvy — an interval-containment comparison over the bounds.
    def depth_of(start, finish)
      @renders.count do |other_start, other_finish, _path|
        other_start <= start && other_finish >= finish &&
          (other_start < start || other_finish > finish)
      end
    end

    # Nest ActiveSupport::Notifications.subscribed blocks so the subscriptions
    # are active only for the duration of the request, then torn down. Each
    # handler takes a single Event (arity 1), which ActiveSupport supplies.
    def with_subscriptions(events, handler, &block)
      return block.call if events.empty?

      event, *rest = events
      ActiveSupport::Notifications.subscribed(handler, event) do
        with_subscriptions(rest, handler, &block)
      end
    end

    def on_render(event)
      return unless current_thread?

      identifier = event.payload[:identifier]
      return unless identifier&.start_with?(@root_prefix)

      @renders << [event.time, event.end, prefixed(identifier.delete_prefix(@root_prefix))]
    end

    def on_controller(event)
      return unless current_thread?

      record_controller(event.payload[:controller])
    end

    # Subscriptions are thread-scoped so concurrent requests don't bleed in.
    def current_thread?
      Thread.current.equal?(@thread)
    end

    # process_action fires after rendering; build the leading pair controller-
    # first by adding the helper, then unshifting the controller ahead of it.
    def record_controller(controller_name)
      return unless controller_name

      path = controller_name.sub(/Controller\z/, "").underscore
      add_leading("app/helpers/#{path}_helper.rb")
      add_leading("app/controllers/#{path}_controller.rb")
    end

    def add_leading(relative)
      return unless File.exist?(File.join(@config.root, relative))

      entry = prefixed(relative)
      @leading.unshift(entry) unless @leading.include?(entry)
    end

    def prefixed(relative)
      "#{@config.path_prefix}#{relative}"
    end
  end
end
