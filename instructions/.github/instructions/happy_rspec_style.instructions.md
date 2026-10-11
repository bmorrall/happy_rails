---
applyTo: "spec/**/*.rb"
---

# Spec code style

- Build and assign values on their own lines before `expect`, not inside its argument, e.g. `decorator = described_class.new(post)` then `expect(decorator.published_on)`, not `expect(described_class.new(post).published_on)` or `expect(post = create(:post))`. This does not apply to the block form, e.g. `expect { post posts_path }.to change(Post, :count).by(1)`.
- Refer to the class under test and its constants through `described_class`, e.g. `described_class.new(api_key: "test-key")` and `raise_error(described_class::UnprocessableError)` in the spec for `NewsletterClient`. Write the full name for any other class, e.g. `NewsletterClient::Error` in an action spec.
