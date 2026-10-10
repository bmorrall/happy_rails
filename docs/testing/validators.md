---
title: Validators
parent: Testing
nav_order: 4
---

# Validators

How I test custom validators.

For the code itself, see [Validators](../../guide/validators/).

## Validator specs

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

## Models and forms that use a validator

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
