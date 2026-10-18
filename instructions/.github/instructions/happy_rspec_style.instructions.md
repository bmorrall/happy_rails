---
applyTo: "spec/**/*.rb"
---

# Spec code style

- Build and assign values on their own lines before `expect`, not inside its argument, e.g. `decorator = described_class.new(post)` then `expect(decorator.published_on)`, not `expect(described_class.new(post).published_on)` or `expect(post = create(:post))`. This does not apply to the block form, e.g. `expect { post posts_path }.to change(Post, :count).by(1)`.
- Refer to the class under test and its constants through `described_class`, e.g. `described_class.new(api_key: "test-key")` and `raise_error(described_class::UnprocessableError)` in the spec for `NewsletterClient`. Write the full name for any other class, e.g. `NewsletterClient::Error` in an action spec.
- Name a spec helper that builds a hash for an example to pass in or match against `a_<thing>_hash`, e.g. `a_newsletter_post_hash` for the body `NewsletterClient` sends, or `a_post_payload_hash` for the JSON body a spec posts to `POST /api/v1/posts`. You MUST NOT name it after the thing alone, e.g. `newsletter_post` or `post_payload`, or start it with `build_`.
- Name every helper in a spec that returns a hash `a_<thing>_hash`, including one that only builds input and is never matched on, so the names in a file stay consistent.
- Name a spec helper that builds an object `a_` then the object's type, e.g. `a_newsletter_client_error` for a `NewsletterClient::Error`. You MUST NOT start it with `build_`, which reads like FactoryBot's `build`.
- Give a spec helper that sets up state a verb name, e.g. `publish_post(post)`, or `stub_newsletter_client_for(integration)`, which also returns the double it stubs. You MUST NOT give it the `a_` prefix.
- Define `a_` helpers at the bottom of the spec file, inside the top-level `describe` or `feature` block, after the examples.
- In a persona context, leave a blank line between the persona's `let`s, i.e. the signed-in `user` and the records that give it its role on the whole app or through a membership, e.g. `let!(:magazine) { create(:magazine, editors: [user]) }`, and the `let`s for the records the context's second argument describes, e.g. `let(:user) { create(:user) }`, a blank line, then `let!(:draft) { create(:post, author: user) }` in `context "as a user", "with a draft post as the author"`.

