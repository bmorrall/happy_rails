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

To test the other service failing, stub the request to fail. Use `.to_return(status: 500)` when the service returns an error, and `.to_timeout` when it takes too long to reply.

```ruby
stub_request(:post, "https://newsletter.example.com/posts").to_timeout
```

Don't call `stub_request` in the specs themselves. Wrap it in a helper for the service, as below. When a spec needs a stub or a check that has no helper yet, add the helper first.

### Helpers and matchers

A stub repeats the service's URL, and often its response body, in every spec that uses it. Put the stubs for each service in a helper module in `spec/support`, with one method for each response the specs need: the reply the service sends when it works, an error and a timeout. Start each method's name with `stub_`, then the service and the request, e.g. `stub_newsletter_create`. Return the WebMock stub from each method.

Then a spec says what the service does, not how its API works. When the API changes, you fix one file, not every spec.

```ruby
# spec/support/newsletter_service.rb
module NewsletterServiceHelpers
  def stub_newsletter_create(id: "newsletter-1")
    stub_request(:post, "https://newsletter.example.com/posts")
      .to_return(status: 201, body: { id: }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_newsletter_create_failure(status: 500)
    stub_request(:post, "https://newsletter.example.com/posts")
      .to_return(status:)
  end

  def stub_newsletter_create_timeout
    stub_request(:post, "https://newsletter.example.com/posts")
      .to_timeout
  end
end

RSpec.configure do |config|
  config.include NewsletterServiceHelpers
end
```

Call the helper inside the example. Avoid calling it in a `let` or a `before` block. Keep the stub it returns in a local variable, and check it with `have_been_requested`. The example then shows the stub and the check together, and the variable says which request you expect.

```ruby
it "sends the post to the newsletter service" do
  post = create(:post)
  newsletter_request = stub_newsletter_create

  described_class.perform_now(post)

  expect(newsletter_request).to have_been_requested
end
```

When a spec also checks what the request sent, e.g. the post's title, add a matcher to the same module. Write it as a method that returns WebMock's own `have_requested` matcher, and use it on `WebMock`. Start its name with `have_requested_`, then the same service and request as the stub, e.g. `have_requested_newsletter_create`. Take only the parts of the request that specs check. When it fails, WebMock lists the requests that were made.

```ruby
# spec/support/newsletter_service.rb
module NewsletterServiceHelpers
  # ...

  def have_requested_newsletter_create(title:)
    have_requested(:post, "https://newsletter.example.com/posts")
      .with(body: hash_including(title:))
  end
end
```

```ruby
it "sends the post's title to the newsletter service" do
  post = create(:post, title: "Hello World")
  stub_newsletter_create

  described_class.perform_now(post)

  expect(WebMock).to have_requested_newsletter_create(title: "Hello World")
end
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

Put SDK stubs behind helpers too, as in [Helpers and matchers](#helpers-and-matchers), e.g. `stub_post_backup_upload`.

## Recording requests

> **TODO:** Describe how you handle this.
