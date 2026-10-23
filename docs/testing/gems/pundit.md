---
title: Pundit
parent: Gems
grand_parent: Testing
nav_order: 6
---

# Pundit

How I test policies.

For the code itself, see [Pundit](../../../guide/gems/pundit/).

A policy reads properties of the user and the record, e.g. `user.app_admin?` or `post.user_is_author?(user)`. Test those properties, not personas. A persona is a mix of properties, so a spec written for personas hides which property gives the access. Request specs cover the personas. See [RSpec: Personas](../rspec/#personas).

Write a `permissions` block for each permission, in the same order as the policy, as in [Pundit: Layout](../../../guide/gems/pundit/#layout): the actions in controller order, then the checks under each heading, e.g. `create_comment?` under `### Comments ###`, then `publish?` under `### Publishing ###`. All of a permission's rules are then in one place, so you can see what it allows and spot a missing case.

Inside the block, write an example for each property of the user the permission reads, and one for a user with none of them. Build the user and the record inside the example, as in [RSpec: Contexts](../rspec/#contexts), and you MUST NOT write contexts. Name the example after the user's property, then the record's when it plays a part, e.g. `"permits a copy editor"` or `"forbids a user with no role for a post another user wrote"`. You MUST NOT name a persona, e.g. "permits an author". When the policy accepts a missing user, pass `nil` and say so in the name, e.g. `"permits a published post when there is no user"`.

Build the user and the record with an `instance_double` or `build_stubbed`. Most permissions only read values, so they don't need the database. Pick the lighter one the policy allows, as in [RSpec: Doubles, build_stubbed or create](../rspec/#doubles-build_stubbed-or-create). Stub a role on the record with an `instance_double` of the model, e.g. `instance_double(Post, user_is_author?: true)`. The model's spec tests how the role is worked out, as in [Models: User access](../../models/#user-access).

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
      user = build_stubbed(:user)
      post = instance_double(Post, user_is_copy_editor?: true)

      expect(described_class).to permit(user, post)
    end

    it "permits a user with no role for a post they wrote" do
      user = build_stubbed(:user)
      post = instance_double(Post, user_is_copy_editor?: false, user_is_author?: true)

      expect(described_class).to permit(user, post)
    end

    it "permits a user with no role for a post they co-author" do
      user = build_stubbed(:user)
      post = instance_double(Post, user_is_copy_editor?: false, user_is_author?: false, user_is_coauthor?: true)

      expect(described_class).to permit(user, post)
    end

    it "forbids a user with no role for a post another user wrote" do
      user = build_stubbed(:user)
      post = instance_double(Post, user_is_copy_editor?: false, user_is_author?: false, user_is_coauthor?: false)

      expect(described_class).not_to permit(user, post)
    end
  end
end
```

Check that each permission forbids as well as permits. Then a policy that starts to permit too much fails its spec. When a permission joins conditions, e.g. `post.published? && user.app_admin?`, write an example where each condition is false on its own. You don't need every combination.

## Scopes

Test the scope in a `describe "Scope"` block, before the `permissions` blocks, as the policy puts it first. Write an example for each property of the user the scope reads, and one for a user with none of them, as in the `permissions` blocks.

The scope runs a query, so build the records with `create`. In each example, create a record the scope returns and one it leaves out, and check the result with `contain_exactly`. Then a scope that returns too much fails its spec. Name the example after what it returns, then the user's property, e.g. `"returns every post for a publishing manager"`.

```ruby
RSpec.describe PostPolicy do
  describe "Scope" do
    it "returns published posts when there is no user" do
      published_post = create(:post, status: :published)
      create(:post)

      expect(described_class::Scope.new(nil, Post.all).resolve).to contain_exactly(published_post)
    end

    it "returns every post for a publishing manager" do
      user = create(:user, :publishing_manager)
      published_post = create(:post, status: :published)
      draft = create(:post)

      expect(described_class::Scope.new(user, Post.all).resolve).to contain_exactly(published_post, draft)
    end

    it "returns the drafts a user with no role wrote" do
      user = create(:user)
      draft = create(:post, author: user)
      create(:post)

      expect(described_class::Scope.new(user, Post.all).resolve).to contain_exactly(draft)
    end

    it "returns the drafts a user with no role co-authors" do
      user = create(:user)
      draft = create(:post, coauthors: [user])
      create(:post)

      expect(described_class::Scope.new(user, Post.all).resolve).to contain_exactly(draft)
    end
  end
end
```

## Setup

Load Pundit's matchers in `spec/support/pundit.rb`, as in [RSpec: Support files](../rspec/#support-files). They add `permissions` blocks and the `permit` matcher to specs in `spec/policies`.

```ruby
# spec/support/pundit.rb
require "pundit/rspec"
```
