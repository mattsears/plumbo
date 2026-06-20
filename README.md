# Plumbo

A zero-config development panel that traces every file behind the page you're
looking at — controller, helper, layout, templates, partials, and the Stimulus
controllers in use — and lets you copy them as `@`-prefixed paths to paste
straight into an AI assistant.

It's **self-contained**: a Rack middleware injects its own HTML, scoped CSS, and
vanilla JS before `</body>`. No Tailwind, no Stimulus, no JS bundler, no view or
layout changes. Drop it into any Rails app.

## Install

```ruby
# Gemfile
group :development do
  gem "plumbo"
end
```

```sh
bundle install
```

That's it. Boot your app in development and a small badge appears in the
bottom-right showing how many files rendered the current page. Click it for the
list; click a row to copy that path, or "Copy All" for the whole list. When the
list gets long, use the filter box to search by path or the type chips
(Controllers, Views, Partials, Stimulus, …) to show just one kind of file.

## How it works

A `Railtie` inserts `Plumbo::Middleware`. For each request the middleware
subscribes (scoped to the request thread) to ActionView's
`render_template` / `render_partial` / `render_layout` notifications and
`process_action.action_controller`, collecting every file under your app root in
render order (controller and helper first), with partials indented under the
template that rendered them. For each rendered template/partial it also scans the
file's source for `data-controller` attributes and nests the matching Stimulus
controllers beneath it, mapping each identifier to its source file via the
standard naming convention (`data-controller="users--list-item"` →
`app/javascript/controllers/users/list_item_controller.js`). On a full HTML
response it injects the panel before `</body>`. Every rendered response also
carries an `X-Plumbo-Files` header listing its files, and the panel's script
reads that header off each `fetch` — so Turbo Drive, Frame, and Stream
navigations (and custom fetch-based panes) all refresh the list without a full
reload. Nothing is added to your asset pipeline.

Only Stimulus controllers written as `data-controller` in a rendered `.erb` are
detected — controllers emitted by helpers/ViewComponents, and other JavaScript
(entry points, plain modules), are not listed.

## Configuration

Defaults are dev-only and need no setup. To override, add an initializer:

```ruby
# config/initializers/plumbo.rb
Plumbo.configure do |c|
  c.enabled          = Rails.env.development?  # default: true only in development
  c.path_prefix      = "@"                     # default "@"; set "" for bare paths
  c.max_files        = 500                     # safety cap on listed files
  c.include_stimulus = true                    # list Stimulus controllers (default true)
  c.javascript_root  = "app/javascript"        # source dir Stimulus paths map into
end
```

## Notes

- The icons are from [Lucide](https://lucide.dev) (ISC license).
- Production-safe: disabled outside development by default, and the middleware
  early-returns when disabled.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
