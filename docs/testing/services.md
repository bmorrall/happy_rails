---
title: Services
parent: Testing
nav_order: 7
---

# Services

How I test service objects.

For the code itself, see [Services](../../guide/services/).

## Service specs

Stub the requests a service makes with the service's stub helpers from `spec/support`. They are the same helpers that request, feature and job specs use, e.g. `stub_newsletter_create`. See [WebMock and VCR: Helpers and matchers](../gems/webmock/#helpers-and-matchers).

The service spec is the one place that checks the service against those stubs. When it passes, every other spec that uses the helpers can trust them. A stub written by hand in a service spec could drift from the helper, and the other specs would no longer test what the service really does.

When a spec needs a response that has no helper yet, add the helper to the service's module, not a `stub_request` to the spec. The next spec that needs it, e.g. a request spec for the same failure, can then use it too. For a service with an SDK that has its own stubs, e.g. `stub_responses` in the AWS SDK, use the SDK's helpers in the same way. See [WebMock and VCR: SDK stubs](../gems/webmock/#sdk-stubs).

### Full messages

Write an example for each major permutation of each method, e.g. each kind of request it sends and each response it handles. In each one, check the whole message both ways:

- **Sent:** the full request body, and every header the service sets. Pass them to the helper module's `have_requested_` matcher. The matcher also checks that the request was made, so you don't need to keep the stub.
- **Received:** every value the service returns, e.g. with `have_attributes` listing each attribute.

Other specs check only the parts they need. The service spec is the one place that pins down the whole message, so it fails when the service drops a field, sends an extra one, or reads the response wrongly.

WebMock matches a body hash exactly, but it only checks the headers you list. List every header the service sets.

```ruby
RSpec.describe NewsletterClient do
  describe "#create_newsletter" do
    it "creates a newsletter for the post" do
      author = build_stubbed(:user, name: "Ada Lovelace")
      post = build_stubbed(:post, title: "Hello World", body: "My first post.", author:)
      stub_newsletter_create(id: "newsletter-1")

      response = described_class.new(api_key: "test-key").create_newsletter(post)

      expect(WebMock).to have_requested_newsletter_create(
        headers: { "Authorization" => "Bearer test-key", "Content-Type" => "application/json" },
        body: {
          title: "Hello World",
          body: "My first post.",
          author_name: "Ada Lovelace"
        }
      )
      expect(response).to have_attributes(id: "newsletter-1")
    end
  end
end
```

## Configuration

Pass a service its settings in specs, instead of stubbing `Rails.application.config.x`. The service takes each setting as a keyword argument, so the spec shows the values it uses, and no other spec sees them, e.g. `described_class.new(api_key: "test-key")` above. Pass only the settings the example needs, and leave the rest to their defaults, so the service's requests still match the stub helpers, e.g. the `base_url`.

### Settings from a record

When the service takes a [connection pool](../../patterns/connection-pools/), pass a test pool as the first argument, e.g. `described_class.new(test_pool, api_key: "test-key")`. Only specs and the service's own class methods pass a pool to `new`.

## Kinds of services

Test a service for the app's own work by calling it with real values, and checking what it returns, e.g. the HTML that `MarkdownRenderer#render_html` makes from Markdown. It makes no requests, so there's nothing to stub. You MUST NOT stub the library it wraps, e.g. Commonmarker. The spec then fails when a new version of the library changes the output. See [Services: Kinds of services](../../guide/services/#kinds-of-services).

```ruby
RSpec.describe MarkdownRenderer do
  describe "#render_html" do
    it "renders Markdown as HTML" do
      html = described_class.new.render_html("Hello **world**")

      expect(html).to eq("<p>Hello <strong>world</strong></p>\n")
    end
  end
end
```

## Errors

Each error the service raises is a major permutation too. Write one example for each, and stub the failure with the service's helpers. Check the service's own error class, not the HTTP library's. See [Services: Errors](../../guide/services/#errors).

With Honeybadger, also check each error's `to_honeybadger_context`. See [Honeybadger: Errors](../gems/honeybadger/#errors).

```ruby
describe "#create_newsletter" do
  # ...

  it "raises an UnprocessableError when the newsletter service rejects the post" do
    post = build_stubbed(:post)
    stub_newsletter_create_failure(status: 422)

    expect { described_class.new(api_key: "test-key").create_newsletter(post) }
      .to raise_error(described_class::UnprocessableError)
  end

  it "raises a TimeoutError when the newsletter service times out" do
    post = build_stubbed(:post)
    stub_newsletter_create_timeout

    expect { described_class.new(api_key: "test-key").create_newsletter(post) }
      .to raise_error(described_class::TimeoutError)
  end
end
```

## Gateways

You MUST NOT stub a service's gateway in its spec, e.g. with `instance_double(NewsletterGateway)`. Stub the requests with the service's helpers, as in [Service specs](#service-specs). The spec then still checks the full message the service sends, through the gateway. See [Services: Gateways](../../guide/services/#gateways).
