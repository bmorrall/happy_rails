---
title: Shoulda Matchers
parent: Gems
grand_parent: The Guide
nav_order: 5
---

# Shoulda Matchers

Validation and association specs with [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers).

## Validations

Test validations with Shoulda Matchers. Assert that a value is allowed or rejected with `allow_value`, not that the record is `valid?` or not. A `valid?` check passes or fails for any reason, so it can pass because of a different validation than the one you meant to test. `allow_value` checks the one attribute and the one value.

Assert the error message as a string for every rejected value, with `with_message`. The spec then shows what the user sees, and fails if the message changes.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "#title" do
    it { is_expected.to allow_value("A title").for(:title) }
    it { is_expected.not_to allow_value("").for(:title).with_message("can't be blank") }
    it { is_expected.not_to allow_value("a" * 101).for(:title).with_message("is too long (maximum is 100 characters)") }
  end
end
```

Use the same matchers for validations on [form objects](../../forms/).

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
