---
title: RSpec and FactoryBot
parent: Gems
grand_parent: The Guide
nav_order: 4
---

# RSpec and FactoryBot

Tests with [RSpec](https://rspec.info) and [FactoryBot](https://github.com/thoughtbot/factory_bot).

## Spec types

> **TODO:** Describe how you handle this.

## Layout and naming

> **TODO:** Describe how you handle this.

## Factories

> **TODO:** Describe how you handle this.

## Traits

> **TODO:** Describe how you handle this.

## Personas

Write a spec for each persona, as described in [Principles: Personas](../../principles/#personas).

Write one `context` for each persona, in rank order, with the Guest last. Name the context after the persona's role, e.g. `"as a publishing manager"`, so the reader can tell what it's for. Use `"when not signed in"` for the Guest. Keep `"as a"` for personas, and name other contexts another way, e.g. `"with a Turbo Stream"`.

For a persona with more than one role, name each role, highest first, e.g. `"as an app admin as the author"`.

Set up the persona inside its context, as a signed-in `user`. Define the `user` and the records the context needs inside the context, not in the `describe` block above it. Don't define a `let` for each persona, e.g. `let(:author)`. Then every context reads on its own, in the same way, and shows how the user gets their access.

For a role on the whole app, build the user with a factory trait. Give the user factory one trait for each role on the whole app, named after the role, e.g. `:app_admin` and `:publishing_manager`. Use a trait for a flag on the user too, e.g. `:employee`. Define the traits in rank order. A plain `create(:user)` is the User persona, with no role.

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password" }

    trait :app_admin do
      role { :app_admin }
    end

    trait :publishing_manager do
      role { :publishing_manager }
    end
  end
end
```

Don't add a trait for a role on a record, e.g. the Author of a post. Build a plain user, then give it the role on the record, e.g. `create(:post, author: user)`. Then the spec shows how the user gets access to that record. For a persona with more than one role, build the user with the trait for the whole-app role, then give it the role on the record.

You can give the user a person's name, e.g. Jane Tester, if it makes the spec easier to read. The context name must still give the role.

```ruby
RSpec.describe "Posts::Publications" do
  describe "POST /posts/:post_id/publication" do
    context "as an app admin" do
      let(:user) { create(:user, :app_admin) }
      let(:draft) { create(:post) }

      before { sign_in user }

      it "publishes the post" do
        post post_publication_path(draft)
        expect(draft.reload).to be_published
      end
    end

    context "as an app admin as the author" do
      let(:user) { create(:user, :app_admin) }
      let(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "publishes the post" do
        post post_publication_path(draft)
        expect(draft.reload).to be_published
      end
    end

    context "as a publishing manager" do
      let(:user) { create(:user, :publishing_manager) }
      let(:draft) { create(:post) }

      before { sign_in user }

      it "publishes the post" do
        post post_publication_path(draft)
        expect(draft.reload).to be_published
      end
    end

    context "as the author" do
      let(:user) { create(:user) }
      let(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "does not publish the post" do
        post post_publication_path(draft)
        expect(draft.reload).not_to be_published
      end
    end

    context "as a user" do
      let(:user) { create(:user) }
      let(:draft) { create(:post) }

      before { sign_in user }

      it "does not publish the post" do
        post post_publication_path(draft)
        expect(draft.reload).not_to be_published
      end
    end

    context "when not signed in" do
      let(:draft) { create(:post) }

      it "does not publish the post" do
        post post_publication_path(draft)
        expect(draft.reload).not_to be_published
      end
    end
  end
end
```

## Request specs

> **TODO:** Describe how you handle this.

## System specs

> **TODO:** Describe how you handle this.
