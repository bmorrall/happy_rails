---
title: WebMock and VCR
parent: Gems
grand_parent: Testing
nav_order: 13
---

# WebMock and VCR

Stubbed HTTP requests in specs with [WebMock](https://github.com/bblimke/webmock) and [VCR](https://github.com/vcr/vcr).

## Stubbing requests

WebMock blocks every real HTTP request in specs. Stub each request the code makes to another service with `stub_request`, inside the service's helpers, as [Other Services](../../other-services/) describes. You MUST NOT call `stub_request` in the specs themselves.

### Helpers

Return the WebMock stub from each helper. Inside a helper, stub a reply with `.to_return`, an error with `.to_return(status: 500)`, and a timeout with `.to_timeout`.

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

In the spec, keep the stub the helper returns in a local variable, and check it with `have_been_requested`. The variable says which request you expect.

```ruby
it "sends the post to the newsletter service" do
  post = create(:post)
  newsletter_request = stub_newsletter_create

  described_class.perform_now(post)

  expect(newsletter_request).to have_been_requested
end
```

### Matchers

For a `have_requested_` matcher, write a method that returns WebMock's own `have_requested` matcher, and use it on `WebMock`. Pass its keywords to WebMock's `with`, e.g. `body:` and `headers:`. Call `with` only when there are keywords. It raises an error when called with no options, so `expect(WebMock).to have_requested_newsletter_create` would break. When the matcher fails, WebMock lists the requests that were made.

```ruby
# spec/support/newsletter_service.rb
module NewsletterServiceHelpers
  # ...

  def have_requested_newsletter_create(**options)
    matcher = have_requested(:post, "https://newsletter.example.com/posts")
    options.any? ? matcher.with(**options) : matcher
  end
end
```

Outside the service's own spec, check only the parts of the request the spec is about, with WebMock's `hash_including`. See [Other Services: Matchers](../../other-services/#matchers).

```ruby
it "sends the post's title to the newsletter service" do
  post = create(:post, title: "Hello World")
  stub_newsletter_create

  described_class.perform_now(post)

  expect(WebMock).to have_requested_newsletter_create(body: hash_including(title: "Hello World"))
end
```

## Recording requests

> **TODO:** Describe how you handle this.
