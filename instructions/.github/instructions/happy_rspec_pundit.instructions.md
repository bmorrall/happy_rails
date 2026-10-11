---
applyTo: "spec/policies/**/*.rb"
---

# Pundit specs

- In policy specs, test the properties of the user and the record that the policy reads, not personas. Write one `permissions` block for each permission, in the same order as the policy layout: the actions in controller order, then the checks under each comment heading in order, e.g. `permissions :show?`, `permissions :update?`, `permissions :create_comment?`, then `permissions :update_published?`. You MUST NOT write contexts in a policy spec.
- In a `permissions` block, write an example for each property of the user the permission reads, and one for a user with none of them. Name the example after the user's property, then the record's when it plays a part, e.g. `it "permits a copy editor"` and `it "forbids a user with no role for a post another user wrote"`. You MUST NOT name a persona, e.g. `it "permits an author"`. When the policy accepts a missing user, pass `nil` and say so in the name, e.g. `expect(described_class).to permit(nil, post)` in `it "permits a published post when there is no user"`.
- In policy specs, build the user and the record inside each example with an `instance_double` or `build_stubbed`, and avoid `create`, e.g. `user = build_stubbed(:user)` and `post = build_stubbed(:post, author: user)` in `it "permits a user with no role for a post they wrote"`. Check with `expect(described_class).to permit(user, post)`.
- In policy specs, check that each permission forbids as well as permits, e.g. `expect(described_class).not_to permit(user, post)` in `it "forbids a post another user wrote"`. When a permission joins conditions, e.g. `post.published? && user.app_admin?`, write an example where each condition is false on its own, not every combination.
