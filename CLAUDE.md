<!-- rails-cto:start -->
## rails-cto

This project uses the [rails-cto](https://github.com/mattsears/rails-cto-gem) gem and its companion [rails-cto Claude plugin](https://github.com/mattsears/rails-cto). Installed configs:

- `.rubocop.yml` — RuboCop with `rubocop-rails`, `rubocop-minitest`, and the `RailsCTO/MinitestSubject` cop.
- `.reek.yml` — Rails-friendly Reek detectors.
- `.bundler-audit.yml` — bundler-audit ignore list.
- `config/brakeman.yml` — Brakeman defaults.
- `.herb/rewriters/align-attributes.mjs` — Herb rewriter for HTML attribute alignment.
- `.herb/rules/no-inline-styles.mjs` — Herb rule forbidding inline `style=""`.
- `test/test_helper.rb` is patched to boot SimpleCov with the JSON formatter (coverage lands at `coverage/coverage.json`).

Invoke `/rails-cto` at the start of every Claude Code session so the plugin's skills can find these configs.
<!-- rails-cto:end -->
