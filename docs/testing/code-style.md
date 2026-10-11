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
