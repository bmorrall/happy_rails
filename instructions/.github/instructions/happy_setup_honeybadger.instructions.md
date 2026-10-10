---
applyTo: "config/honeybadger.yml,app/models/concerns/honeybadger_cause_context.rb"
---

# Honeybadger setup

- Write the `HoneybadgerCauseContext` concern in `app/models/concerns/honeybadger_cause_context.rb`, which defines `to_honeybadger_context` as `cause.respond_to?(:to_honeybadger_context) ? cause.to_honeybadger_context : {}`.
- TODO: How to set up Honeybadger.
