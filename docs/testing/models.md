---
title: Models
parent: Testing
nav_order: 3
---

# Models

How I test models.

For the code itself, see [Models](../../guide/models/).

## Building records

Build the record under test with `described_class.new`, not a factory. Pass only the attributes the example needs. The spec then shows everything the result depends on, and a change to a factory can't break it.

```ruby
RSpec.describe Post do
  describe "#published?" do
    it "is true for a published post" do
      post = described_class.new(status: :published)

      expect(post).to be_published
    end
  end
end
```

## Spec layout

Name the `subject` after the model, e.g. `subject(:post)`, and use `is_expected` where you can. When an example needs a record with different attributes, build it in the example, e.g. `post = described_class.new(title: "A title")`. You MUST NOT add a `let`, or another `subject`, for it. The example then shows the record it checks.

Group a model's examples in a `describe` block for each method, named after the method, e.g. `describe "#published?"`. For an association, name the block after the association, e.g. `describe "#author"`, and put the examples for its id attribute, e.g. `author_id`, in the same block. Everything about one method or association is then in one place.

Group the examples for each gem's Modules heading in one `describe` block named after the gem, e.g. `describe "FriendlyId"`. Put everything under that heading in it: what the gem's setup does, e.g. the slug it sets, and the methods of its `concerning` block, e.g. `#should_generate_new_friendly_id?`. The spec then matches the model, where both sit under `### Modules (FriendlyId) ###`. You MUST NOT add a `describe` block for the `concerning` block itself.

Group the examples for a `concerning` block under Public Methods in one `describe` block named after it, e.g. `describe "Publishing"` for `concerning :Publishing`. Put every method the block defines inside it, including scopes and class methods. Keep the examples in the model's spec. A `concerning` block lives in the model file, so its spec lives in the model's spec. If the examples outgrow the model's spec, move the code into its own file, e.g. a concern in `app/models/concerns`, and give that file its own spec.

Order the blocks in four tiers, each in alphabetical order:

1. Class methods and scopes, e.g. `describe ".recent"`
2. Instance methods, attributes and associations, e.g. `describe "#author"` and `describe "#published?"`
3. Modules, e.g. `describe "FriendlyId"`
4. Concerns, e.g. `describe "Publishing"`

Alphabetical order needs no judgement about which group a method belongs to, e.g. whether `published?` comes from an enum or a method. The tiers follow RSpec's prefixes: `.` for a class method and `#` for an instance method.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe ".recent" do
    # ...
  end

  describe "#author" do
    it { is_expected.to belong_to(:author).class_name("User") }

    it "does not allow a banned user" do
      banned_user = create(:user, :banned)

      expect(post).not_to allow_value(banned_user.id).for(:author_id).with_message("can't be a banned user")
    end
  end

  describe "#published?" do
    # ...
  end

  describe "FriendlyId" do
    describe "#slug" do
      # ...
    end

    describe "#should_generate_new_friendly_id?" do
      it "is true when the title changes" do
        post = described_class.new(title: "A title")

        expect(post.should_generate_new_friendly_id?).to be(true)
      end
    end
  end

  describe "Publishing" do
    describe "#recently_published?" do
      # ...
    end
  end
end
```

## Validations and associations

Test validations and associations with Shoulda Matchers. See [Shoulda Matchers: Validations](../gems/shoulda_matchers/#validations) and [Shoulda Matchers: Associations](../gems/shoulda_matchers/#associations).

Test an attribute that uses a custom validator with the validator's matcher, e.g. `it { is_expected.to validate_isbn_format_of(:isbn) }`. You MUST NOT repeat the cases from the validator's own spec. See [Validators: Models and forms that use a validator](../validators/#models-and-forms-that-use-a-validator).

## Scopes

Scopes are an exception to building records with `described_class.new`. A scope queries the database, so its spec needs saved records. Create them with factories, and check the records the scope returns. Comparing the scope's `to_sql` with the query you expect also works, but a spec with records checks the result the scope is for.

```ruby
RSpec.describe Post do
  describe ".recent" do
    it "returns the newest post first" do
      older_post = create(:post, created_at: 2.days.ago)
      newer_post = create(:post, created_at: 1.day.ago)

      expect(described_class.recent).to eq([newer_post, older_post])
    end
  end
end
```

## User access

Test each role in the `UserAccess` block with the `grant_user_access` matcher. It checks `user_is_<role>?` and `for_user_as_<role>` together, and fails if either one disagrees. Then the method and its scope can't drift apart without a failing spec. Check that a role is withheld with `not_to`, which needs both to say no.

Pass the matcher a record, an array or a relation, e.g. `expect(drafts).to grant_user_access(user, as: :copy_editor)`. It checks every record, and `not_to` checks that none of them is granted.

Put the `grant_user_access` examples straight in the `describe "UserAccess"` block, in role rank order. You MUST NOT group them in a `describe` block for a role or a method, e.g. `describe "copy editor"`. Each example covers two methods, so no one method names it. Any other method in the block gets its own `describe` block as usual, as in [Spec layout](#spec-layout). Name each one after what it grants or denies, and to whom, e.g. `"grants drafts to a copy editor"`.

For each role, write an example that grants it, and one that denies it to a user without the role. When a role has a condition, test a record on each side of it, e.g. a draft and a published post for a copy editor.

The matcher queries the scope, so create the records with factories, as for a scope.

```ruby
RSpec.describe Post do
  describe "UserAccess" do
    it "grants drafts to a copy editor" do
      user = create(:user, :copy_editor)
      drafts = create_list(:post, 2)

      expect(drafts).to grant_user_access(user, as: :copy_editor)
    end

    it "denies a published post to a copy editor" do
      user = create(:user, :copy_editor)
      post = create(:post, status: :published)

      expect(post).not_to grant_user_access(user, as: :copy_editor)
    end

    it "denies a draft to a user with no role as copy editor" do
      user = create(:user)
      post = create(:post)

      expect(post).not_to grant_user_access(user, as: :copy_editor)
    end

    # ...

    it "grants a post the user co-authors" do
      user = create(:user)
      post = create(:post, coauthors: [user])

      expect(post).to grant_user_access(user, as: :coauthor)
    end

    it "denies another user's post as co-author" do
      user = create(:user)
      post = create(:post)

      expect(post).not_to grant_user_access(user, as: :coauthor)
    end
  end
end
```

Define the matcher in a `UserAccessSpecHelpers` module, as in [RSpec: Where to put matchers](../gems/rspec/#where-to-put-matchers), and include it in model specs. The `match_when_negated` block makes `not_to` need both sides to say no for every record. Without it, RSpec would flip `match`, and a record that only one side denied would pass.

```ruby
# spec/support/user_access_spec_helpers.rb
module UserAccessSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :grant_user_access do |user, as:|
    match do |actual|
      read_access(actual, user, as)
      @results.all? { |result| result[:method] && result[:scope] }
    end

    match_when_negated do |actual|
      read_access(actual, user, as)
      @results.none? { |result| result[:method] || result[:scope] }
    end

    failure_message do
      "expected #{as} access to every record, but:\n#{describe_results(as)}"
    end

    failure_message_when_negated do
      "expected no #{as} access to any record, but:\n#{describe_results(as)}"
    end

    private

    def read_access(actual, user, role)
      records = Array(actual)
      scope_ids = records.first.class.public_send(:"for_user_as_#{role}", user).where(id: records).pluck(:id)

      @results = records.map do |record|
        {
          record: record,
          method: record.public_send(:"user_is_#{role}?", user),
          scope: scope_ids.include?(record.id)
        }
      end
    end

    def describe_results(role)
      @results.map do |result|
        "  #{result[:record].inspect}: user_is_#{role}? returned #{result[:method]}, " \
          "for_user_as_#{role} #{result[:scope] ? "included" : "left out"} it"
      end.join("\n")
    end
  end
end

RSpec.configure do |config|
  config.include UserAccessSpecHelpers, type: :model
end
```

## Callbacks

Test a callback by what it does, through the call that triggers it in the app. You MUST NOT call the callback method itself, and you MUST NOT test that the callback is registered. Put the examples in the `describe` block of the attribute the callback changes, and say in each description what triggers it, e.g. "when saved" or "when validated". When the callback has a condition, test both sides of it.

A save callback runs on `save`, which needs a valid record, so build the record with a factory, as for scopes.

```ruby
RSpec.describe Post do
  describe "#published_at" do
    it "is set when a published post is saved" do
      travel_to Time.zone.now

      post = build(:post, status: :published, published_at: nil)

      post.save!

      expect(post.published_at).to eq(Time.zone.now)
    end

    it "is not set when a draft post is saved" do
      post = build(:post, status: :draft, published_at: nil)

      post.save!

      expect(post.published_at).to be_nil
    end
  end
end
```

A validation callback, e.g. `before_validation`, runs on `validate`. Call `validate` on a record built with `described_class.new`, so no factory is needed.

```ruby
RSpec.describe Post do
  describe "#reading_time" do
    it "is set from the body when validated" do
      post = described_class.new(body: "word " * 400)

      post.validate

      expect(post.reading_time).to eq(2)
    end
  end
end
```

Test a normalisation in the `describe` block of its attribute. Build the record with the untidy value, and read the attribute back. It runs when the attribute is set, so there's no need to call `validate` or `save`.

```ruby
RSpec.describe Post do
  describe "#title" do
    it "is stripped" do
      post = described_class.new(title: "  A title  ")

      expect(post.title).to eq("A title")
    end
  end
end
```
