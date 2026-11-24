---
title: Code Style
parent: Testing
nav_order: 14
---

# Code Style

My own style preferences for specs, on top of what RuboCop checks.
{: .fs-5 .fw-300 }

These are preferences, not Happy Rails conventions. Nothing else in the guide depends on them. If your app has its own style, skip this page and delete `happy_rspec_style.instructions.md`.

For the code itself, see [Code Style](../../guide/code-style/).

## Preferences

### Expectations

Build and assign values before `expect`, not inside its argument. Give each value its own line in the setup, then pass the variable to `expect`. Then the `expect` line only says what is checked, and each value has a name you can read.

```ruby
it "returns the unknown value tag for a draft" do
  post = instance_double(Post, published_at: nil)
  decorator = described_class.new(post)

  expect(decorator.published_on).to have_unknown_value_tag
end
```

You MUST NOT write `expect(described_class.new(post).published_on)` or `expect(post = create(:post))`. This doesn't apply to the block form, e.g. `expect { post posts_path }.to change(Post, :count).by(1)`, where the block is the action being checked.

### described_class

Refer to the class under test through `described_class`, including its constants, e.g. its errors. Then the spec reads the same whatever the class is called, and a rename only changes the `RSpec.describe` line. Write the full name for any other class, e.g. a service's error in an action spec.

```ruby
RSpec.describe NewsletterClient do
  describe "#create_newsletter" do
    it "raises an UnprocessableError when the newsletter service rejects the newsletter" do
      stub_newsletter_create_failure(status: 422)

      expect { described_class.new(api_key: "test-key").create_newsletter(title: "Hello World", body: "") }
        .to raise_error(described_class::UnprocessableError)
    end
  end
end
```

### Helper names

Name a helper method that builds a value for an example to pass in or match against with `build_`, the thing, then the kind of value it returns, e.g. `build_newsletter_body_hash`. The `build_` prefix sets the helper apart from a `let` and from the methods on the code under test. The suffix says what kind of value comes back, so the helper isn't mistaken for a record or a matcher.

A `build_` helper builds a new value each time it's called, from the arguments the example passes, e.g. `title:`. You MUST NOT memoise it, e.g. with `@newsletter_body_hash ||=`. A `let` gives back the same value every time an example reads it. When an example needs the same value twice, assign it to a variable.

A `build_` helper only builds its value and returns it, so it is always safe to call. You MUST NOT change state in it, e.g. create a record, stub a request, or set an instance variable. A helper that does is a setup helper, as below.

Name a helper that builds a hash `build_<thing>_hash`, e.g. `build_newsletter_body_hash` for the body `NewsletterClient` sends, or `build_post_payload_hash` for the JSON body a spec posts to `POST /api/v1/posts`. You MUST NOT name it after the thing alone, e.g. `newsletter_body` or `post_payload`. Name every helper in the spec that returns a hash this way, including one that only builds input and is never matched on, so the names in a file stay consistent.

Name a helper that builds an object `build_` then the object's type, e.g. `build_newsletter_client_error` for a `NewsletterClient::Error`.

A helper that sets up state keeps a verb that says what it does, e.g. `publish_post(post)`, or `stub_newsletter_client_for(integration)`, which also returns the double it stubs. You MUST NOT give it the `build_` prefix.

Define `build_` helpers at the bottom of the spec file, inside the top-level `describe` or `feature` block, after the examples.

```ruby
RSpec.describe NewsletterClient do
  describe "#create_public_newsletter" do
    it "creates a public newsletter" do
      stub_newsletter_create

      described_class.new(api_key: "test-key").create_public_newsletter(title: "Hello World", body: "My first post.")

      expect(WebMock).to have_requested_newsletter_create(body: build_newsletter_body_hash(title: "Hello World", body: "My first post."))
    end
  end

  def build_newsletter_body_hash(title:, body:)
    {
      title:,
      body:,
      visibility: "public"
    }
  end
end
```

### let groups

In a persona context, leave a blank line between the persona's `let`s and the `let`s for the records it acts on. The persona's `let`s are the signed-in `user` and the records that give it its role on the whole app or through a membership, e.g. the magazine a Magazine Editor edits. The record `let`s build what the context's second argument describes, including the record the persona holds a role on. The two groups then match the two parts of the context's name, e.g. `"as a user"` and `"with a draft post as the author"`.

When the context declares `valid_params`, put it in a group of its own, after the record `let`s and a blank line. It holds the request, not a record the context's name describes. See [Controllers and Routes: Strong parameters](../controllers/#strong-parameters).

```ruby
context "as a user", "with a draft post as the author" do
  let(:user) { create(:user) }

  let!(:draft) { create(:post, author: user) }

  let(:valid_params) { { title: "New title", body: "My first post." } }

  before { sign_in user }

  # ...
end
```
