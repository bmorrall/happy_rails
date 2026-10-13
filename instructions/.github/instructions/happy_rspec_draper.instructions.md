---
applyTo: "spec/decorators/**/*.rb,spec/support/**/*.rb"
---

# Draper specs

- Write a decorator spec in `spec/decorators` for each decorator, with a `describe` block for each method and an example for each path through it, e.g. `it "returns the date it was published"` and `it "returns the unknown value tag for a draft"` for `PostDecorator#published_on`.
- In decorator specs, build the record being decorated on its own line, then decorate it on the next line, e.g. `post = instance_double(Post, published_at: nil)` and `decorator = PostDecorator.new(post)`.
- In decorator specs, check an element built with a helper with the helper's matcher, e.g. `expect(decorator.published_on).to have_unknown_value_tag`. You MUST NOT compare it with markup or the helper's output, e.g. `eq(helpers.unknown_value_tag)`. Include each helper's matcher module for `type: :decorator`, e.g. `config.include UnknownValuesSpecHelpers, type: :decorator` in `spec/support/unknown_values_spec_helpers.rb`.
- In decorator specs, when a method returns a link or the unknown value tag, check the unknown case with `have_unknown_value_tag.and(have_no_link)`, e.g. `expect(decorator.scheduled_by_link).to have_unknown_value_tag.and(have_no_link)` in `it "returns the unknown value tag when no one scheduled the post"`.
- In decorator specs, test a method that reads its context by building the record in the example, decorated the same way the controller passes it, and passing it in the decorator's context, e.g. `tag = TagDecorator.new(instance_double(Tag, to_param: "2"))` and `described_class.new(post, context: { tag: tag })` in `it "links to the post under the tag"` for `PostDecorator#tag_post_link`.
- Spec each `can_` method you override, with an example for each path, e.g. `it "allows it when the policy allows it and the post has no comments"`, `it "forbids it when the policy forbids it"` and `it "forbids it when the post has comments"` for `PostDecorator#can_destroy?`. You MUST NOT spec the plain `can_` delegates.
- In decorator specs, stub the policy in each example that needs it, not at the top of the spec, with an `instance_double` of the policy class returned from `helpers.policy`, e.g. `allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: true))`.
