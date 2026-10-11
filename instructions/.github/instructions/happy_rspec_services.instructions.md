---
applyTo: "spec/services/**/*.rb"
---

# Service specs

- Pass a service its settings in specs, e.g. `described_class.new(api_key: "test-key")`, instead of stubbing `Rails.application.config.x`.
- When the service takes a connection pool, pass a test pool as the first argument, e.g. `described_class.new(test_pool, api_key: "test-key")`. See https://bmorrall.github.io/happy_rails/patterns/connection-pools/.
- TODO: How to test services.
