# Honeybadger setup

Rules: `.github/instructions/happy_honeybadger.instructions.md`, `.github/instructions/happy_rspec_honeybadger.instructions.md`

- Write the `HoneybadgerCauseContext` concern in `app/models/concerns/honeybadger_cause_context.rb`, which defines `to_honeybadger_context` as `cause.respond_to?(:to_honeybadger_context) ? cause.to_honeybadger_context : {}`. Copy `assets/app/models/concerns/honeybadger_cause_context.rb`.
- When the app uses RSpec, make every example that calls `Honeybadger.notify` fail unless it is tagged `:honeybadger`, and make every tagged example expect at least one call and call the original, in `spec/support/honeybadger.rb`. Copy `assets/spec/support/honeybadger.rb`.
- TODO: How to set up Honeybadger.
