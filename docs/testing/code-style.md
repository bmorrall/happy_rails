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
    it "raises an UnprocessableError when the newsletter service rejects the post" do
      post = build_stubbed(:post)
      stub_newsletter_create_failure(status: 422)

      expect { described_class.new(api_key: "test-key").create_newsletter(post) }
        .to raise_error(described_class::UnprocessableError)
    end
  end
end
```
