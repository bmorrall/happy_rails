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

A report is part of what the code does, so every spec that makes one says so. Tag each example that reports an error to Honeybadger with `:honeybadger`. Tag the example itself, not its `context` or `describe` block, so each report sits next to its check. Every other example fails when the code calls `Honeybadger.notify`, so a new report can't slip in unnoticed, and a report that goes missing fails the tagged example.

Set this up once, in `spec/support/honeybadger.rb`. A tagged example expects at least one call to `Honeybadger.notify`, and calls the original, so the gem still builds the notice. An untagged example expects no call.

```ruby
# spec/support/honeybadger.rb
RSpec.configure do |config|
  config.before do |example|
    if example.metadata[:honeybadger]
      expect(Honeybadger).to receive(:notify).at_least(:once).and_call_original
    else
      expect(Honeybadger).not_to receive(:notify)
    end
  end
end
```

The hook only checks that the code reported something. In each tagged example, check each call itself with `have_received`: the error and the context it passes. You MUST NOT stub `Honeybadger.notify` in the spec, e.g. `allow(Honeybadger).to receive(:notify)`. The hook already does it.

Unit specs check the details, and integration specs check the outline. An integration spec, e.g. a request or job spec, checks that the code reported the error, and which records the report includes. Check each record's context there with the record's own `to_honeybadger_context`, e.g. `context: { post: published_post.to_honeybadger_context }`. You SHOULD NOT write the hash out. Each hash is written out in one unit spec: a record's in its model spec, as in [Context](#context), and an error's in the spec for the service or action that builds it, as in [Errors](#errors).

```ruby
it "reports the error to Honeybadger when the newsletter service fails", :honeybadger do
  published_post = create(:post)
  stub_newsletter_create_failure

  post post_newsletter_path(published_post)

  expect(Honeybadger).to have_received(:notify).with(
    an_instance_of(Posts::SendNewsletter::ServiceError),
    context: { post: published_post.to_honeybadger_context }
  )
end
```

A unit spec that reports an error, e.g. a form or action spec, builds its records with `instance_double`. Stub `to_honeybadger_context` on the double with a small hash, and check that the report passes it on, e.g. `instance_double(Post, to_honeybadger_context: { id: 1 })` then `context: { post: { id: 1 } }`.

## Context

Check a model's `to_honeybadger_context` in its model spec, in a `describe "#to_honeybadger_context"` block. Match the whole hash with `eq`, so a key that goes missing or holds the wrong value fails here, and not in every spec that checks a report. Add an example for each association it reads with `&.`, with the associated record missing, so the method can't raise an error while the app reports one.

```ruby
RSpec.describe Comment do
  describe "#to_honeybadger_context" do
    it "returns the comment's details for error reports" do
      created_at = Time.zone.now
      post = Post.new(id: 2, title: "Hello World")
      comment = described_class.new(id: 1, locked: false, created_at:, post:)

      expect(comment.to_honeybadger_context).to eq(
        id: 1,
        locked: false,
        created_at:,
        post_id: 2,
        post_title: "Hello World"
      )
    end

    it "returns the post's ID when the post is missing" do
      comment = described_class.new(post_id: 2)

      expect(comment.to_honeybadger_context).to include(post_id: 2, post_title: nil)
    end
  end
end
```

### Errors

When a service's or action's error defines its own `to_honeybadger_context`, check it in that spec's example for each error. Match the whole hash with `eq`, in the block you pass to `raise_error`. The report is the one place you see the request and response when the service fails, so a key that goes missing or holds the wrong value has to fail a spec. See [Services: Errors](../../services/#errors).

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
