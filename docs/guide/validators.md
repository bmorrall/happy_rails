---
title: Validators
parent: The Guide
nav_order: 4
---

# Validators

How custom validators are written and used.

Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`. Rails loads them from there, and any model, form or action can use them.

## When to write a validator

> **TODO:** Describe how you handle this.

## Writing a validator

### Naming and layout

> **TODO:** Describe how you handle this.

### Blank values

Rails' own validators, other than `presence`, check a blank value like any other, e.g. `length: { minimum: 3 }` fails for `nil`. Pass `allow_blank: true` or `allow_nil: true` to skip blank values. A custom validator that inherits from `ActiveModel::EachValidator` gets both options for free. Rails checks them before it calls `validate_each`.

Write custom validators the same way. Never skip a blank value inside `validate_each`. Treat it like any other value that fails the check, and let the caller decide with `allow_blank` or `allow_nil`. Then every validator in the app handles blank values the same way.

When an attribute also has `presence: true`, add `allow_blank: true` to its other validators. A blank value then gets one error, "can't be blank", not a stack of errors that all say it's missing.

```ruby
validates :title, presence: true, length: { minimum: 3, allow_blank: true }
validates :post, presence: true, unmodified: { allow_blank: true }
```

### Values of the wrong kind

A validator usually checks a value by calling a method on it, e.g. `has_changes_to_save?`. Check that the value responds to that method first. When it doesn't, add `:invalid`. A value of the wrong kind then fails like any other bad value, instead of passing quietly or raising `NoMethodError`.

```ruby
class ExampleValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return record.errors.add(attribute, :invalid, **options) unless value.respond_to?(:example?)
    return if value.example?

    record.errors.add(attribute, :example, **options)
  end
end
```

Name the arguments to `validate_each` as Rails does: `record`, `attribute` and `value`. The validator then reads the same wherever it is used, e.g. in a model, a form or an action.

### Format validators

When a value must match a pattern, e.g. a UUID, inherit from Rails' `ActiveModel::Validations::FormatValidator`, and give it the pattern in `initialize`. The validator then works like `format:`. It adds `:invalid`, it handles `allow_blank:`, `message:` and `strict:`, and every caller checks the same pattern.

```ruby
class UuidValidator < ActiveModel::Validations::FormatValidator
  UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  def initialize(options)
    super(options.merge(with: UUID_FORMAT).reverse_merge(message: :invalid_uuid))
  end
end
```

Set the pattern with `merge`, so a caller can't replace it. Set the default message with `reverse_merge`, so a caller can still pass its own. Use a symbol for the message, e.g. `:invalid_uuid`, so it comes from the locale file, as in [Default messages](#default-messages).

```yaml
# config/locales/en.yml
en:
  errors:
    messages:
      invalid_uuid: "is not a valid UUID"
```

Use it like any other validator, e.g. on the ID a caller generates with `SecureRandom.uuid` for another service. See [Actions: Return values](../actions/#return-values).

```ruby
validates :newsletter_id, uuid: { allow_blank: true }
```

Use a format validator only when matching the pattern is the whole rule. If a value also needs another check, e.g. a check digit, write an `ActiveModel::EachValidator` instead, as in [Example: IsbnValidator](#example-isbnvalidator).

### Example: IsbnValidator

An ISBN must match a pattern, and its last digit must be the right check digit. `IsbnValidator` checks both, and follows every rule above:

- A value that isn't a string fails as `:invalid`, as in [Values of the wrong kind](#values-of-the-wrong-kind).
- It doesn't skip blank values. The caller passes `allow_blank: true`, as in [Blank values](#blank-values).
- An ISBN with the wrong format or check digit fails with its own symbol, `:invalid_isbn`, with its message in the locale file.
- Every `errors.add` passes `**options`, so `message:` and `strict:` still work.

```ruby
class IsbnValidator < ActiveModel::EachValidator
  ISBN_FORMAT = /\A(?:\d{9}[\dX]|97[89]\d{10})\z/

  def validate_each(record, attribute, value)
    return record.errors.add(attribute, :invalid, **options) unless value.respond_to?(:to_str)
    return if ISBN_FORMAT.match?(value) && valid_check_digit?(value)

    record.errors.add(attribute, :invalid_isbn, **options)
  end

  private

  def valid_check_digit?(isbn)
    digits = isbn.chars.map { |char| char == "X" ? 10 : char.to_i }

    if digits.size == 10
      digits.each_with_index.sum { |digit, index| digit * (10 - index) } % 11 == 0
    else
      digits.each_with_index.sum { |digit, index| digit * (index.even? ? 1 : 3) } % 10 == 0
    end
  end
end
```

```yaml
# config/locales/en.yml
en:
  errors:
    messages:
      invalid_isbn: "is not a valid ISBN"
```

```ruby
validates :isbn, presence: true, isbn: { allow_blank: true }
```

The validator checks the value as it is, so an ISBN with hyphens fails. Tidy the value in the model first, e.g. `normalizes :isbn, with: ->(isbn) { isbn.delete("-") }`.

## I18n

Add each error with a symbol, e.g. `:modified`, not a sentence. Rails uses the symbol to look up the message in the locale files, so you can change the wording, or translate it, without changing the validator.

### How Rails finds the message

For `errors.add(:post, :modified)` with no `message:`, Rails tries these keys in order, and uses the first one it finds:

1. `activemodel.errors.models.posts/publish_post.attributes.post.modified`, for this attribute of this class
2. `activemodel.errors.models.posts/publish_post.modified`, for any attribute of this class
3. `activemodel.errors.messages.modified`, for any Active Model class
4. `errors.attributes.post.modified`, for this attribute name in any class
5. `errors.messages.modified`, for everything

The first part of the first three keys is the class's I18n scope. It is `activemodel` for actions and forms, and `activerecord` for models. Each step is more general than the one before, so you set the default once in `errors.messages`, and override it only where one class or attribute needs different words.

If none of the keys exist, the message is a "Translation missing" note that lists every key Rails tried. A user should never see it.

### Missing messages

Make a missing message fail in development and in specs. Rails generates `config.i18n.raise_on_missing_translations` commented out in both environment files. Uncomment it in each.

```ruby
# config/environments/development.rb and config/environments/test.rb
config.i18n.raise_on_missing_translations = true
```

A validator that adds an error with no message in the locale files then raises `I18n::MissingTranslationData`, which lists every key Rails tried. A spec for the validator fails until you add the message, so the note never reaches a user.

### Default messages

Never pass a default message as a string. When `message:` is a string, Rails checks only the first key, for this attribute of this class. If that's missing, it uses the string and skips the rest, so the locale file can't change the message.

Put the default message in `config/locales/en.yml`, which every Rails app has, under `en.errors.messages`. Pass the validator's `options` to every `errors.add` with `**options`, as Rails' own validators do. A caller's `message:` then still wins, and other options, e.g. `strict: true`, still work. `errors.add` ignores the options that only decide when the validation runs, e.g. `allow_blank:` and `if:`.

```yaml
# config/locales/en.yml
en:
  errors:
    messages:
      example: "is not an example"
```

```ruby
record.errors.add(attribute, :example, **options)
```

Then every key in [How Rails finds the message](#how-rails-finds-the-message) works, and a caller can still pass its own message, e.g. `example: { message: "isn't one of ours" }`.

## Common validators

Validators that most apps need. Add the ones you use to `app/validators/`.

### UnmodifiedValidator

`UnmodifiedValidator` checks that a record has no unsaved changes. Use it in an action that includes `ValidatedCallable`, on each record argument, e.g. `validates :post, presence: true, unmodified: { allow_blank: true }`. It catches a caller that passes a record with unsaved changes, which the guide never allows. See [Actions: Arguments](../actions/#arguments) and [Actions: Checking arguments](../actions/#checking-arguments).

```ruby
class UnmodifiedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return record.errors.add(attribute, :invalid, **options) unless value.respond_to?(:has_changes_to_save?)
    return unless value.has_changes_to_save?

    record.errors.add(attribute, :modified, **options)
  end
end
```

Add the error with a symbol, `:modified`, so code and specs can check which error it is, e.g. `errors.of_kind?(:post, :modified)`. Put its default message in the locale file, as in [Default messages](#default-messages). A caller can pass its own, e.g. `unmodified: { message: "is being edited" }`.

```yaml
# config/locales/en.yml
en:
  errors:
    messages:
      modified: "has unsaved changes"
```

Unmodified means no unsaved changes at all, whether the record is saved or not. A new record built with values, e.g. `Post.new(title:)`, has changes to save, so it fails the check. A value that isn't a record, e.g. an ID, fails as `:invalid`, as in [Values of the wrong kind](#values-of-the-wrong-kind). So does `nil`, so add `allow_blank: true` next to `presence: true`. A missing argument then only gets "can't be blank". See [Blank values](#blank-values).

```ruby
module Posts
  class PublishPost < ApplicationAction
    include ValidatedCallable

    validates :post, :publisher, presence: true, unmodified: { allow_blank: true }

    # ...
  end
end
```

A failed check is a bug in the caller, so never rescue it. See [Actions: Checking arguments](../actions/#checking-arguments).

## Testing

Write a unit spec for each validator, in `spec/validators/`, e.g. `spec/validators/isbn_validator_spec.rb`. Test the validator on its own, as if any app could use it. Never test it with one of the app's models or forms, e.g. `Post`. The validator doesn't know about them, and its spec shouldn't either.

Build the validator under test with `described_class`, and run it against a stand-in record. Never rely on the option name to find it, e.g. `validates :value, isbn: true`. Then the spec runs the class it describes, even if the option name and the class name stop matching.

Make the stand-in record a `Struct` with one attribute, called `value`, that includes `ActiveModel::Validations`. Give it a `name`, which Rails needs to build error messages. Pass the validator's options in each example, e.g. `message:`.

```ruby
RSpec.describe IsbnValidator do
  subject(:record) { record_class.new }

  let(:record_class) do
    Struct.new(:value) do
      include ActiveModel::Validations

      def self.name = "Record"
    end
  end

  def validate(value, **options)
    record.value = value
    described_class.new(attributes: [:value], **options).validate(record)
  end

  it "allows a valid ISBN" do
    validate("9780306406157")

    expect(record.errors[:value]).to be_empty
  end

  it "rejects an ISBN with the wrong check digit" do
    validate("9780306406158")

    expect(record.errors).to be_of_kind(:value, :invalid_isbn)
    expect(record.errors[:value]).to eq(["is not a valid ISBN"])
  end

  it "rejects a value that isn't a string" do
    validate(9780306406157)

    expect(record.errors).to be_of_kind(:value, :invalid)
  end

  it "uses the message it is given" do
    validate("9780306406158", message: "is not an ISBN we know")

    expect(record.errors[:value]).to eq(["is not an ISBN we know"])
  end
end
```

Check each error by its type, with `be_of_kind`, and by its message. The type is what code and specs rely on, and the message is what the user sees. Cover:

- each kind of valid value, e.g. an ISBN-10 and an ISBN-13
- each way a value can fail, e.g. the wrong format or the wrong check digit
- a value of the wrong kind, e.g. an integer, and a blank value, e.g. `nil`
- an option the validator passes on, e.g. `message:`

Don't test Rails' own options, e.g. `allow_blank:` or `strict:`. Rails handles them, and passing `**options` is enough for them to work.

### Models and forms that use a validator

A model or form spec checks that an attribute uses the validator, not every case the validator handles. The validator's own spec covers those. Give each validator a matcher named after it, e.g. `validate_isbn_of` for `IsbnValidator`. The matcher checks one value the validator allows and one it rejects, with Shoulda Matchers' `allow_value`, as for any validation. See [Shoulda Matchers: Validations](../gems/shoulda_matchers/#validations).

Check what the validator does, not that it's declared. Never look it up with `validators_on`, for the same reason the guide never tests that a callback is registered.

Put the matcher in a module named after the validator, with a `SpecHelpers` suffix, in `spec/support/`. Include it for model specs and form specs, with `type: :model` and `type: :form`. See [RSpec: Form specs](../gems/rspec/#form-specs).

```ruby
# spec/support/isbn_validator_spec_helpers.rb
module IsbnValidatorSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :validate_isbn_of do |attribute|
    chain(:with_message) { |message| @message = message }

    match(notify_expectation_failures: true) do |record|
      expect(record).to allow_value("9780306406157").for(attribute)
      expect(record).not_to allow_value("9780306406158").for(attribute).with_message(@message || "is not a valid ISBN")
    end
  end
end

RSpec.configure do |config|
  config.include IsbnValidatorSpecHelpers, type: :model
  config.include IsbnValidatorSpecHelpers, type: :form
end
```

Use the matcher in the `describe` block of the attribute. When the attribute sets its own message, pass it with `with_message`.

```ruby
describe "#isbn" do
  it { is_expected.to validate_isbn_of(:isbn) }
end
```

Use these matchers with `to` only, like Shoulda Matchers' own `validate_` matchers. A spec that checks an attribute doesn't use a validator tests nothing the user can see.
