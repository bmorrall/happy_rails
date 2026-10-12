---
title: Pundit
parent: Gems
grand_parent: Testing
nav_order: 4
---

# Pundit

How I test policies.

For the code itself, see [Pundit](../../../guide/gems/pundit/).

A policy reads properties of the user and the record, e.g. `user.copy_editor?` or `post.author_id == user.id`. Test those properties, not personas. A persona is a mix of properties, so a spec written for personas hides which property gives the access. Request specs cover the personas. See [RSpec: Personas](../rspec/#personas).

Write a `permissions` block for each permission, in the same order as the policy, as in [Pundit: Layout](../../../guide/gems/pundit/#layout): the actions in controller order, then the checks under each heading, e.g. `create_comment?` under `### Comments ###`, then `update_published?` under `### Publishing ###`. All of a permission's rules are then in one place, so you can see what it allows and spot a missing case.

Inside the block, write an example for each property of the user the permission reads, and one for a user with none of them. Build the user and the record inside the example, as in [RSpec: Contexts](../rspec/#contexts), and you MUST NOT write contexts. Name the example after the user's property, then the record's when it plays a part, e.g. `"permits a copy editor"` or `"forbids a user with no role for a post another user wrote"`. You MUST NOT name a persona, e.g. "permits an author". When the policy accepts a missing user, pass `nil` and say so in the name, e.g. `"permits a published post when there is no user"`.

Build the user and the record with an `instance_double` or `build_stubbed`. Most permissions only read values, so they don't need the database. Pick the lighter one the policy allows, as in [RSpec: Doubles, build_stubbed or create](../rspec/#doubles-build_stubbed-or-create). A check through the user's association reads the database, e.g. `user.coauthored_posts.include?(post)`, so build those records with `create`.

```ruby
RSpec.describe PostPolicy do
  permissions :show? do
    it "permits a published post when there is no user" do
      post = build_stubbed(:post, status: :published)

      expect(described_class).to permit(nil, post)
    end

    it "forbids a draft when there is no user" do
      post = build_stubbed(:post)

      expect(described_class).not_to permit(nil, post)
    end
  end

  permissions :update? do
    it "permits a copy editor" do
      user = build_stubbed(:user, :copy_editor)
      post = build_stubbed(:post)

      expect(described_class).to permit(user, post)
    end

    it "permits a user with no role for a post they wrote" do
      user = build_stubbed(:user)
      post = build_stubbed(:post, author: user)

      expect(described_class).to permit(user, post)
    end

    it "permits a user with no role for a post they co-author" do
      user = create(:user)
      post = create(:post, coauthors: [user])

      expect(described_class).to permit(user, post)
    end

    it "forbids a user with no role for a post another user wrote" do
      user = create(:user)
      post = create(:post)

      expect(described_class).not_to permit(user, post)
    end
  end
end
```

Check that each permission forbids as well as permits. Then a policy that starts to permit too much fails its spec. When a permission joins conditions, e.g. `post.published? && user.app_admin?`, write an example where each condition is false on its own. You don't need every combination.

## Setup

Load Pundit's matchers in `spec/support/pundit.rb`, as in [RSpec: Support files](../rspec/#support-files). They add `permissions` blocks and the `permit` matcher to specs in `spec/policies`.

```ruby
# spec/support/pundit.rb
require "pundit/rspec"
```
