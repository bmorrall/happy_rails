---
applyTo: "spec/**/*.rb"
---

# Spec code style

- Build and assign values on their own lines before `expect`, not inside its argument, e.g. `decorator = described_class.new(post)` then `expect(decorator.published_on)`, not `expect(described_class.new(post).published_on)` or `expect(post = create(:post))`. This does not apply to the block form, e.g. `expect { post posts_path }.to change(Post, :count).by(1)`.
