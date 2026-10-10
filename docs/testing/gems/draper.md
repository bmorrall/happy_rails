---
title: Draper
parent: Gems
grand_parent: Testing
nav_order: 2
---

# Draper

How I test decorators.

For the code itself, see [Draper](../../../guide/gems/draper/).

## Decorator specs

Write a decorator spec in `spec/decorators` for each decorator. Give each method its own `describe` block, and write an example for each path through it. A method with an `if` needs one example for each side. Build the record inside each example. See [RSpec: Contexts](../rspec/#contexts).

Build the record being decorated on its own line, then decorate it on the next line. Use an `instance_double` that stubs only the values the method reads. When it can't stand in for the record, e.g. for a method that passes the record to a route helper, like `h.link_to(object.title, object)`, use `build_stubbed`. See [RSpec: Doubles, build_stubbed or create](../rspec/#doubles-build_stubbed-or-create).

```ruby
RSpec.describe PostDecorator do
  describe "#published_on" do
    it "returns the date it was published" do
      post = instance_double(Post, published_at: Time.zone.local(2026, 10, 3, 9, 30))
      decorator = described_class.new(post)

      expect(decorator.published_on).to have_date_tag(Date.new(2026, 10, 3))
    end

    it "returns the unknown value tag for a draft" do
      post = instance_double(Post, published_at: nil)
      decorator = described_class.new(post)

      expect(decorator.published_on).to have_unknown_value_tag
    end
  end
end
```

When a method returns an element built with a helper, check it with the helper's matcher, e.g. `have_date_tag` and `have_unknown_value_tag`, not with the markup or the helper's output. See [RSpec: Matchers for helpers](../rspec/#matchers-for-helpers). The decorator spec then checks for the element the same way as the request and feature specs do, and doesn't break when the helper's markup changes. Include each helper's matcher module in decorator specs.

```ruby
# spec/support/unknown_values_spec_helpers.rb
RSpec.configure do |config|
  # ...
  config.include UnknownValuesSpecHelpers, type: :decorator
end
```

A decorator spec covers the presentation logic for a record, so you don't need a helper spec for it. See [Draper: When to use a decorator](../../../guide/gems/draper/#when-to-use-a-decorator).

## Context

To spec a method that reads its context, e.g. `tag_post_link`, build the record in the example, decorated the same way the controller passes it, e.g. a `TagDecorator`. Then pass it in the decorator's context. Only the examples that need the context build it, and each one shows which record it gets.

```ruby
RSpec.describe PostDecorator do
  describe "#tag_post_link" do
    it "links to the post under the tag" do
      post = instance_double(Post, title: "Hello", to_param: "1")
      tag = TagDecorator.new(instance_double(Tag, to_param: "2"))
      decorator = described_class.new(post, context: { tag: tag })

      expect(decorator.tag_post_link).to eq('<a href="/tags/2/posts/1">Hello</a>')
    end
  end
end
```

## Permissions

Spec each `can_` method that you override, e.g. `can_destroy?`, with an example for each path: the policy forbids it, the business rule forbids it, and both allow it. Don't spec the plain delegates. The policy spec covers who may do what.

Stub the policy, so the spec doesn't need a signed-in user. Build it with an `instance_double` of the policy class, and stub `helpers.policy` to return it. `helpers` is the same view context the decorator reads through `h`. Stub it in each example, not at the top of the spec, so each example shows the permission it runs with, and specs for other methods don't build a policy.

```ruby
RSpec.describe PostDecorator do
  describe "#can_destroy?" do
    it "allows it when the policy allows it and the post has no comments" do
      post = instance_double(Post, comments: [])
      allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: true))
      decorator = described_class.new(post)

      expect(decorator.can_destroy?).to be(true)
    end

    it "forbids it when the policy forbids it" do
      post = instance_double(Post, comments: [])
      allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: false))
      decorator = described_class.new(post)

      expect(decorator.can_destroy?).to be(false)
    end

    it "forbids it when the post has comments" do
      post = instance_double(Post, comments: [instance_double(Comment)])
      allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: true))
      decorator = described_class.new(post)

      expect(decorator.can_destroy?).to be(false)
    end
  end
end
```
