---
applyTo: "spec/**/*.rb"
---

# Spec code style

- Build and assign values on their own lines before `expect`, not inside its argument, e.g. `decorator = described_class.new(post)` then `expect(decorator.published_on)`, not `expect(described_class.new(post).published_on)` or `expect(post = create(:post))`. This does not apply to the block form, e.g. `expect { post posts_path }.to change(Post, :count).by(1)`.
- Refer to the class under test and its constants through `described_class`, e.g. `described_class.new(api_key: "test-key")` and `raise_error(described_class::UnprocessableError)` in the spec for `NewsletterClient`. Write the full name for any other class, e.g. `NewsletterClient::Error` in an action spec.
- Name a spec helper that builds a value for an example to pass in or match against with `build_`, e.g. `build_newsletter_body_hash`, so it is set apart from a `let` and from the methods on the code under test.
- Build a new value on each call to a `build_` spec helper, from the arguments the example passes, e.g. `build_newsletter_body_hash(title: "Hello World", body: "My first post.")`. You MUST NOT memoise it, e.g. with `@newsletter_body_hash ||=`. When an example needs the same value twice, assign it to a variable.
- Only build and return a value in a `build_` spec helper, so it is always safe to call. You MUST NOT change state in it, e.g. create a record, stub a request, or set an instance variable. Give a helper that does a verb that says what it does, e.g. `publish_post(post)`.
- Name a spec helper that builds a hash `build_<thing>_hash`, e.g. `build_newsletter_body_hash` for the body `NewsletterClient` sends, or `build_post_payload_hash` for the JSON body a spec posts to `POST /api/v1/posts`. You MUST NOT name it after the thing alone, e.g. `newsletter_body` or `post_payload`.
- Name every helper in a spec that returns a hash `build_<thing>_hash`, including one that only builds input and is never matched on, so the names in a file stay consistent.
- Name a spec helper that builds an object `build_` then the object's type, e.g. `build_newsletter_client_error` for a `NewsletterClient::Error`.
- Give a spec helper that sets up state a verb that says what it does, e.g. `publish_post(post)`, or `stub_newsletter_client_for(integration)`, which also returns the double it stubs. You MUST NOT give it the `build_` prefix.
- Define `build_` helpers at the bottom of the spec file, inside the top-level `describe` or `feature` block, after the examples.
- In a persona context, leave a blank line between the persona's `let`s, i.e. the signed-in `user` and the records that give it its role on the whole app or through a membership, e.g. `let!(:magazine) { create_magazine_with_magazine_editor(user) }`, and the `let`s for the records the context's second argument describes, e.g. `let(:user) { create(:user) }`, a blank line, then `let!(:draft) { create(:post, author: user) }` in `context "as a user", "with a draft post as the author"`.
- In a persona context that declares `valid_params`, put it in a group of its own, after the record `let`s and a blank line, e.g. `let!(:draft) { create(:post, author: user) }`, a blank line, then `let(:valid_params) { { title: "New title", body: "My first post." } }`.
