---
applyTo: "spec/services/**/*.rb"
---

# Service specs

- In service specs, stub the service's requests with its stub helpers from `spec/support`, the same helpers that request, feature and job specs use, e.g. `stub_newsletter_create(id: "newsletter-1")`.
- When a service spec needs a response that has no helper yet, add the helper to the service's module in `spec/support`, so other specs can use it too. For a service whose SDK has its own stubs, use the SDK's helpers the same way, e.g. `stub_post_backup_upload`.
- Write an example for each major permutation of each service method, e.g. each kind of request it sends and each response it handles.
- In each permutation, check the full message sent: pass the full request body and every header the service sets to the helper module's `have_requested_` matcher, e.g. `expect(WebMock).to have_requested_newsletter_create(headers: { "Authorization" => "Bearer test-key", "Content-Type" => "application/json" }, body: { title: "Hello World", body: "My first post.", idempotency_key: a_string_matching(/\Apost-#{post.id}-\h{32}\z/) })`. The matcher checks that the request was made, so you don't need to keep the stub.
- In each permutation, check every value the service returns, e.g. `expect(response).to have_attributes(id: "newsletter-1")`.
- Pass a service its settings in specs, e.g. `described_class.new(api_key: "test-key")`, instead of stubbing `Rails.application.config.x`. Pass only the settings the example needs, and leave the rest to their defaults, so the requests still match the stub helpers.
- When the service takes a connection pool, pass a test pool as the first argument, e.g. `described_class.new(test_pool, api_key: "test-key")`. See https://bmorrall.github.io/happy_rails/patterns/connection-pools/.
- Write one example for each error the service raises, stub the failure with the service's helpers, and check the service's own error class, e.g. `stub_newsletter_create_failure(status: 422)` then `expect { described_class.new(api_key: "test-key").create_newsletter(post) }.to raise_error(described_class::UnprocessableError)`.
