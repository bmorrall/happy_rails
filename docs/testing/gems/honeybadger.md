---
title: Honeybadger
parent: Gems
grand_parent: Testing
nav_order: 5
---

# Honeybadger

How I test error reporting with Honeybadger.

For the code itself, see [Honeybadger](../../../guide/gems/honeybadger/).

## Reporting errors

> **TODO:** Describe how you handle this.

## Context

### Errors

When a service's error defines `to_honeybadger_context`, check it in the service spec's example for each error. Match the whole hash with `eq`, in the block you pass to `raise_error`. The report is the one place you see the request and response when the service fails, so a key that goes missing or holds the wrong value has to fail a spec. See [Services: Errors](../../services/#errors).

```ruby
it "raises an UnprocessableError when the newsletter service rejects the newsletter" do
  stub_newsletter_create_failure(status: 422)

  expect { described_class.new(api_key: "test-key").create_newsletter(title: "Hello World", body: "") }
    .to raise_error(described_class::UnprocessableError) do |error|
      expect(error.to_honeybadger_context).to eq(
        request_method: :post,
        request_url: "https://newsletter.example.com/posts",
        response_status: 422,
        response_body: ""
      )
    end
end
```

When an action raises its own error in place of a service's error, check in the action spec that the report keeps the service's details. In the example where the service fails, check that the error's `cause` is the service's error, and that `to_honeybadger_context` is the cause's context. The service spec already checks the hash itself, so this example only checks that the context is passed on. It fails when the action's error no longer includes `HoneybadgerCauseContext`, or is raised without the cause.

Stub the service to raise an error built with the details a real failure carries, as in [Actions](../../actions/). The example below uses the `newsletter_client` from the action spec's `let`. Ruby sets it as the `cause` when the action raises inside `rescue`.

```ruby
it "raises a ServiceError when the newsletter service fails" do
  post = instance_double(Post, title: "Hello World", body: "My first post.")
  allow(newsletter_client).to receive(:create_newsletter).with(title: "Hello World", body: "My first post.")
    .and_raise(NewsletterClient::Error.new("Server error", status: 500))

  expect { described_class.call(post) }.to raise_error(described_class::ServiceError) do |error|
    expect(error.cause).to be_a(NewsletterClient::Error)
    expect(error.to_honeybadger_context).to eq(error.cause.to_honeybadger_context)
  end
end
```

Give `HoneybadgerCauseContext` its own spec, in `spec/models/concerns/honeybadger_cause_context_spec.rb`. Check the two paths: a cause with context, and a cause without it. Build an error class that includes the concern, and raise it with `cause:`.

```ruby
RSpec.describe HoneybadgerCauseContext do
  it "returns the context of the error's cause" do
    error_class = Class.new(StandardError) { include HoneybadgerCauseContext }
    cause = NewsletterClient::Error.new(
      "Server error",
      http_method: :post,
      url: "https://newsletter.example.com/posts",
      status: 500,
      body: "Server error"
    )

    expect { raise error_class, cause: }.to raise_error(error_class) do |error|
      expect(error.to_honeybadger_context).to eq(
        request_method: :post,
        request_url: "https://newsletter.example.com/posts",
        response_status: 500,
        response_body: "Server error"
      )
    end
  end

  it "returns an empty hash when the cause has no context" do
    error_class = Class.new(StandardError) { include HoneybadgerCauseContext }

    expect { raise error_class, cause: StandardError.new }.to raise_error(error_class) do |error|
      expect(error.to_honeybadger_context).to eq({})
    end
  end
end
```
