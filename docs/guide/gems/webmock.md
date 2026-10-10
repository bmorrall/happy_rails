---
title: WebMock and VCR
parent: Gems
grand_parent: The Guide
nav_order: 9
---

# WebMock and VCR

Stubbed HTTP requests in specs with [WebMock](https://github.com/bblimke/webmock) and [VCR](https://github.com/vcr/vcr).

## Stubbing requests

WebMock blocks every real HTTP request in specs. Stub each request the code makes to another service with `stub_request`, and check that the code made it. Stub the request, not the service class that makes it, so the spec runs the service's code too.

```ruby
newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")
  .with(body: hash_including(title: "Hello World"))

described_class.perform_now(post)

expect(newsletter_request).to have_been_requested
```

To test the other service failing, stub the request to fail. Use `.to_return(status: 500)` when the service returns an error, and `.to_timeout` when it takes too long to reply.

```ruby
stub_request(:post, "https://newsletter.example.com/posts").to_timeout
```

### SDK stubs

Some services come with an SDK that has its own stubs, e.g. `stub_responses` in the AWS SDK. Use them instead of WebMock. They replace only the SDK's HTTP layer, so your service's code still runs, and you don't write signed requests or response bodies by hand. Never stub the service class itself.

Turn the stubs on for every spec, and set the responses for a spec in `Aws.config`. Remove them after each spec, so they don't leak into the next one.

```ruby
# spec/support/aws.rb
Aws.config.update(stub_responses: true)

RSpec.configure do |config|
  config.after { Aws.config.delete(:s3) }
end
```

To check the request, stub the response with a block that keeps its params.

```ruby
it "saves a copy of the post to S3" do
  post = create(:post, published_at: Time.zone.now)
  uploads = []
  Aws.config[:s3] = {
    stub_responses: { put_object: ->(context) { uploads << context.params; {} } }
  }

  described_class.perform_now(post)

  expect(uploads).to contain_exactly(hash_including(key: "posts/#{post.id}.json"))
end
```

To test the service failing, stub the response with the error's code, e.g. `Aws.config[:s3] = { stub_responses: { put_object: "ServiceUnavailable" } }`. The client then raises `Aws::S3::Errors::ServiceUnavailable`.

## Recording requests

> **TODO:** Describe how you handle this.
