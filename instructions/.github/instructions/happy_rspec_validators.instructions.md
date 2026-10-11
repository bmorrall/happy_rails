---
applyTo: "spec/validators/**/*.rb"
---

# Validator specs

- Write a unit spec for each validator in `spec/validators/`. Build the validator under test with `described_class`, and run it against a stand-in record, e.g. `described_class.new(attributes: [:value], **options).validate(record)` with `record` from `Struct.new(:value) { include ActiveModel::Validations; def self.name = "Record" }`. You MUST NOT find the validator by its option name, e.g. `validates :value, isbn: true`, and you MUST NOT use the app's models or forms in a validator spec, e.g. `Post`.
- In validator specs, check each error's type and message, e.g. `expect(record.errors).to be_of_kind(:value, :invalid_isbn)` and `expect(record.errors[:value]).to eq(["is not a valid ISBN"])`. Cover each kind of valid value, each way a value can fail, a blank value and `message:`. You MUST NOT test Rails' own options, e.g. `allow_blank:`.
- Give each validator a matcher for model and form specs, named `validate_<name>_of`, e.g. `validate_isbn_of` in `IsbnValidatorSpecHelpers` in `spec/support/isbn_validator_spec_helpers.rb`, included for `type: :model` and `type: :form`. In it, check one allowed and one rejected value with `allow_value`, with a `with_message` chain, e.g. `expect(record).not_to allow_value("9780306406158").for(attribute).with_message(@message || "is not a valid ISBN")`. You MUST NOT check `validators_on`. Use it with `to` only.
