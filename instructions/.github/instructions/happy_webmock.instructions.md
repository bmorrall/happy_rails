---
applyTo: "spec/**/*.rb"
---

# WebMock and VCR

- Stub each HTTP request the code makes to another service with `stub_request`, and assert that it was made, e.g. `newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")` then `expect(newsletter_request).to have_been_requested`. Never stub the service class that makes the request, e.g. `allow(NewsletterClient).to receive(:new)`.
- To test another service failing, stub the request to fail: `.to_return(status: 500)` when it returns an error, e.g. `stub_request(:post, "https://newsletter.example.com/posts").to_return(status: 500)`, or `.to_timeout` when it takes too long to reply, e.g. `stub_request(:post, "https://newsletter.example.com/posts").to_timeout`.
- When a service's SDK has its own stubs, use them instead of WebMock, e.g. `stub_responses` in the AWS SDK.
- Turn on AWS SDK stubs for every spec in `spec/support/aws.rb` with `Aws.config.update(stub_responses: true)`, and remove each service's stubbed responses after each spec, e.g. `config.after { Aws.config.delete(:s3) }`.
- Set a spec's AWS responses in `Aws.config`, and check the request with a block that keeps its params, e.g. `Aws.config[:s3] = { stub_responses: { put_object: ->(context) { uploads << context.params; {} } } }` then `expect(uploads).to contain_exactly(hash_including(key: "posts/#{post.id}.json"))`.
- To test an AWS service failing, stub the response with the error's code, e.g. `Aws.config[:s3] = { stub_responses: { put_object: "ServiceUnavailable" } }`.
- TODO: How to record and replay HTTP requests with VCR.
