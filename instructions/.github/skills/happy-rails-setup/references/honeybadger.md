# Honeybadger setup

Rules: `.github/instructions/happy_honeybadger.instructions.md`

- Write the `HoneybadgerCauseContext` concern in `app/models/concerns/honeybadger_cause_context.rb`, which defines `to_honeybadger_context` as `cause.respond_to?(:to_honeybadger_context) ? cause.to_honeybadger_context : {}`. Copy `assets/app/models/concerns/honeybadger_cause_context.rb`.
- TODO: How to set up Honeybadger.
