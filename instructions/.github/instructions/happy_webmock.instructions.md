---
applyTo: "spec/**/*.rb"
---

# WebMock and VCR

- Stub each HTTP request the code makes to another service, and assert that it was made. Never stub the service class that makes the request, e.g. `allow(NewsletterClient).to receive(:new)`.
- In specs, stub requests with the service's helpers from `spec/support`, e.g. `stub_newsletter_create`. Never call `stub_request` in a spec. When the helper you need doesn't exist yet, add it to the service's support file first.
- Put the stubs for each service in a helper module in `spec/support`, included in every spec, with one method for each response the specs need: success, error and timeout, e.g. `stub_newsletter_create`, `stub_newsletter_create_failure` and `stub_newsletter_create_timeout` in `NewsletterServiceHelpers` in `spec/support/newsletter_service.rb`. Start each name with `stub_`, then the service and the request, and return the WebMock stub.
- Inside a helper, stub an error with `.to_return(status: 500)` and a timeout with `.to_timeout`, e.g. `stub_request(:post, "https://newsletter.example.com/posts").to_timeout` in `stub_newsletter_create_timeout`.
- Call stub helpers inside the example. Avoid calling them in a `let` or `before` block. Keep the returned stub in a local variable and check it with `have_been_requested`, e.g. `newsletter_request = stub_newsletter_create` then `expect(newsletter_request).to have_been_requested`.
- When a spec checks what a request sent, add a matcher to the service's helper module, as a method that returns WebMock's `have_requested` matcher. Name it `have_requested_` followed by the same service and request as the stub, take only the parts of the request the specs check, and use it on `WebMock`, e.g. `have_requested_newsletter_create(title:)` returns `have_requested(:post, "https://newsletter.example.com/posts").with(body: hash_including(title:))`, used as `expect(WebMock).to have_requested_newsletter_create(title: "Hello World")`.
- When a service's SDK has its own stubs, use them instead of WebMock, e.g. `stub_responses` in the AWS SDK.
- Turn an SDK's stubs on for every spec in a `spec/support` file named after the SDK, and remove each service's stubbed responses after each spec, e.g. `Aws.config.update(stub_responses: true)` and `config.after { Aws.config.delete(:s3) }` in `spec/support/aws.rb`.
- Set a spec's AWS responses in `Aws.config` inside a helper in `spec/support`, e.g. `stub_post_backup_upload`, and check the request with a block that keeps its params, e.g. `Aws.config[:s3] = { stub_responses: { put_object: ->(context) { uploads << context.params; {} } } }` then `expect(uploads).to contain_exactly(hash_including(key: "posts/#{post.id}.json"))`.
- To test an AWS service failing, stub the response with the error's code, e.g. `Aws.config[:s3] = { stub_responses: { put_object: "ServiceUnavailable" } }`.
- TODO: How to record and replay HTTP requests with VCR.
