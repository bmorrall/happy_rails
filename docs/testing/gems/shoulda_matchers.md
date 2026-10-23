---
title: Shoulda Matchers
parent: Gems
grand_parent: Testing
nav_order: 8
---

# Shoulda Matchers

Validation and association specs with [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers).

## Validations

Test a validation that Shoulda Matchers has a matcher for with that matcher, written as a one-liner. The matcher knows how the validator behaves, so it checks the edge cases for you, e.g. the value one past the maximum length. This covers Rails' built-in validators, including those that compare two attributes, e.g. `validate_comparison_of(:ends_at).is_greater_than(:starts_at)`.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "#title" do
    it { is_expected.to validate_presence_of(:title).with_message("can't be blank") }
    it { is_expected.to validate_length_of(:title).is_at_most(Post::TITLE_MAX_LENGTH).with_message("is too long (maximum is 100 characters)") }
  end

  describe "#word_count" do
    it { is_expected.to validate_numericality_of(:word_count).is_greater_than(0).with_message("must be greater than 0") }
  end
end
```

### Uniqueness

Test uniqueness with `validate_uniqueness_of`. The matcher needs a saved record to compare with. Create one with a factory first, so the matcher doesn't save the subject with missing values, e.g. without an `author_id`. The subject still comes from `described_class.new`.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "#slug" do
    it "is unique" do
      create(:post)

      expect(post).to validate_uniqueness_of(:slug).with_message("has already been taken")
    end
  end
end
```

The matcher checks that uniqueness is case-sensitive by default. Add `.case_insensitive` only when the validation sets `case_sensitive: false`. Add `.ignoring_case_sensitivity` only when the model changes the value's case itself, e.g. with a `normalizes` that downcases it. Otherwise the matcher can't tell the two cases apart.

### Validations without a matcher

When no matcher covers a validation, or it's too complex for its matcher, e.g. a format, a custom rule or a uniqueness rule scoped through another model, test the values it accepts and rejects with `allow_value`. `allow_value` checks one attribute and one value. Create any records the rule checks against with a factory.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "#slug" do
    it { is_expected.to allow_value("my-post").for(:slug) }
    it { is_expected.not_to allow_value("My Post").for(:slug).with_message("is invalid") }

    it "does not allow the slug of an existing post" do
      existing_post = create(:post)

      expect(post).not_to allow_value(existing_post.slug).for(:slug).with_message("has already been taken")
    end
  end
end
```

### Error messages

Assert the error message as a string for every value `allow_value` rejects, with `with_message`. The spec then shows what the user sees, and fails if the message changes.

A `validate_*` matcher SHOULD have `with_message` too, e.g. `it { is_expected.to validate_presence_of(:title).with_message("can't be blank") }`. Without it, the matcher checks Rails' default message. The spec then doesn't show the message, and a change to the validation's message or the locale file might not fail it.

### `valid?`

You MUST NOT assert `valid?`, `invalid?` or `be_valid` to test a validation. A `valid?` check passes or fails for any reason, so it can pass because of a different validation than the one you meant to test. A matcher, or `allow_value`, checks the one attribute.

### Form objects

Use the same matchers for validations on [form objects](../../../guide/forms/). Shoulda Matchers only includes them in `type: :model` specs, so include them for form specs in `spec/support/shoulda_matchers.rb`. Form specs get `type: :form` from [RSpec: Form specs](../rspec/#form-specs).

```ruby
# spec/support/shoulda_matchers.rb
RSpec.configure do |config|
  config.include Shoulda::Matchers::ActiveModel, type: :form
end
```

## Associations

Test each association with its Shoulda Matchers matcher, e.g. `belong_to`, `have_one` or `have_many`. Add a qualifier for each option the association declares, e.g. `class_name` or `dependent`, so the spec fails if an option changes.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "#author" do
    it { is_expected.to belong_to(:author).class_name("User") }
  end

  describe "#comments" do
    it { is_expected.to have_many(:comments).dependent(:destroy) }
  end
end
```
