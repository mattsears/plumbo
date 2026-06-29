# Plumbo

A zero-config development panel that lists every file behind the page you're
looking at — controller, helper, layout, templates, partials, and the Stimulus
controllers in use — so you can copy their paths straight into an AI assistant.

Paths copy `@`-prefixed (e.g. `@app/views/posts/index.html.erb`), ready to paste
as file mentions. Plumbo is **self-contained**: a Rack middleware injects its own
HTML, CSS, and JavaScript — nothing is added to your asset pipeline, and there are
no view, layout, or bundler changes. Drop it into any Rails app.

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

That's it. Boot your app in development and a badge appears in the bottom-right
showing how many files rendered the current page.

## Using the panel

- **Click the badge** to open the list — a tree, in render order, with partials
  and Stimulus controllers nested (and color-coded) under their parent.
- **Collapse or expand** a parent by clicking its row; **copy** a single path with
  its copy icon, or **Copy All** for the whole (filtered) list.
- **Hover a row** to highlight the part of the page that file rendered — a partial
  used in a loop lights up every instance. Rows with no on-page output (controllers,
  helpers, JavaScript) simply don't highlight.
- **Filter** by typing in the search box, or click a type chip — Controllers,
  Views, Partials, Stimulus, … — to show just one kind.
- **Clear All** empties the list so you can watch fresh files appear as you click
  around. The list keeps up with Turbo (Drive, Frames, and Streams) without a
  full page reload.

## Configuration

Defaults are dev-only and need no setup. To override, add an initializer:

```ruby
# config/initializers/plumbo.rb
Plumbo.configure do |c|
  c.enabled          = Rails.env.development?  # default: true only in development
  c.path_prefix      = "@"                     # default "@"; set "" for bare paths
  c.max_files        = 500                     # safety cap on listed files
  c.include_stimulus = true                    # list Stimulus controllers
  c.javascript_root  = "app/javascript"        # source dir Stimulus paths map into
  c.highlight        = true                     # highlight a file's region on hover
end
```

## How it works

A Railtie inserts a Rack middleware that subscribes to ActionView's render
notifications for each request, collecting every file under your app root in call
order. It also scans rendered templates for `data-controller` attributes and maps
each to its Stimulus source file. The panel is injected into full HTML pages, and
every response carries an `X-Plumbo-Files` header that the panel reads on each
`fetch` to stay current across Turbo navigations.

> Only Stimulus controllers written as `data-controller` in a rendered `.erb` are
> detected — those emitted by helpers or ViewComponents, and other JavaScript,
> aren't listed.

Hover highlighting reuses Rails' built-in
`annotate_rendered_view_with_filenames`, which Plumbo enables in development so each
rendered template and partial is wrapped in `<!-- BEGIN … -->`/`<!-- END … -->`
comments. The panel reads those markers to locate a file's output on the page. This
adds the comments to your development HTML; set `c.highlight = false` to leave the
markup untouched (the panel still lists files, just without hover highlighting).

## Notes

- Production-safe: disabled outside development by default.
- Icons from [Lucide](https://lucide.dev) (ISC license).

## License

MIT — see [LICENSE.txt](LICENSE.txt).
