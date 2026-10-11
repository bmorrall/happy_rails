---
applyTo: "spec/**/*.rb"
---

# Honeybadger specs

- When a service's error defines `to_honeybadger_context`, check the whole hash with `eq` in the service spec's example for each error, in the block passed to `raise_error`, e.g. `.to raise_error(described_class::UnprocessableError) do |error|` then `expect(error.to_honeybadger_context).to eq(request_method: :post, request_url: "https://newsletter.example.com/posts", response_status: 422, response_body: "")`.
- When an action raises its own error in place of a service's error, check in the action spec's example for the service failing that the error's `cause` is the service's error and that its `to_honeybadger_context` is the cause's, e.g. `expect(error.cause).to be_a(NewsletterClient::Error)` and `expect(error.to_honeybadger_context).to eq(error.cause.to_honeybadger_context)` in the block passed to `raise_error(described_class::ServiceError)`. Stub the service to raise an error built with the details a real failure carries, e.g. `.and_raise(NewsletterClient::Error.new("Server error", status: 500))`.
- Give `HoneybadgerCauseContext` its own spec in `spec/models/concerns/honeybadger_cause_context_spec.rb`, with one example for a cause with context and one for a cause without it. Build an error class that includes the concern and raise it with `cause:`, e.g. `error_class = Class.new(StandardError) { include HoneybadgerCauseContext }` then `expect { raise error_class, cause: StandardError.new }.to raise_error(error_class) do |error|` and `expect(error.to_honeybadger_context).to eq({})`.
- TODO: How to test error reporting.
