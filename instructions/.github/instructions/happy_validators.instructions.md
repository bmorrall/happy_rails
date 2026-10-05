---
applyTo: "app/validators/**/*.rb,spec/validators/**/*.rb"
---

# Validators

- Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`.
- In a custom validator, never skip blank values in `validate_each`, e.g. `return if value.blank?`. Leave them to the caller's `allow_blank:` or `allow_nil:`.
- In a custom validator, add `:invalid` when the value doesn't respond to the method the check calls, e.g. `return record.errors.add(attribute, :invalid, **options) unless value.respond_to?(:example?)`.
- Name the arguments to `validate_each` as Rails does, e.g. `def validate_each(record, attribute, value)`.
- When matching a pattern is the whole rule, inherit from `ActiveModel::Validations::FormatValidator` and set the pattern and a default message symbol in `initialize`, e.g. `super(options.merge(with: UUID_FORMAT).reverse_merge(message: :invalid_uuid))` in `UuidValidator`, with `invalid_uuid: "is not a valid UUID"` in `en.errors.messages`. When a value also needs another check, e.g. an ISBN's check digit, write an `ActiveModel::EachValidator` instead.
- Add a validator's errors with a symbol, never a sentence, e.g. `errors.add(attribute, :modified)`, so the message can come from the locale files.
- Put a validator's default message in `config/locales/en.yml` under `en.errors.messages`, e.g. `modified: "has unsaved changes"`. Pass the validator's `options` to every `errors.add`, e.g. `record.errors.add(attribute, :modified, **options)`. Never pass a default message string.
- Set `config.i18n.raise_on_missing_translations = true` in `config/environments/development.rb` and `config/environments/test.rb`, so an error with no message in the locale files raises.
- `UnmodifiedValidator` adds a `:modified` error if `value.has_changes_to_save?`.
- Write a unit spec for each validator in `spec/validators/`. Build the validator under test with `described_class`, and run it against a stand-in record, e.g. `described_class.new(attributes: [:value], **options).validate(record)` with `record` from `Struct.new(:value) { include ActiveModel::Validations; def self.name = "Record" }`. Never find the validator by its option name, e.g. `validates :value, isbn: true`, and never use the app's models or forms in a validator spec, e.g. `Post`.
- In validator specs, check each error's type and message, e.g. `expect(record.errors).to be_of_kind(:value, :invalid_isbn)` and `expect(record.errors[:value]).to eq(["is not a valid ISBN"])`. Cover each kind of valid value, each way a value can fail, a value of the wrong kind, a blank value and `message:`. Never test Rails' own options, e.g. `allow_blank:`.
- Give each validator a matcher for model and form specs, named `validate_<name>_of`, e.g. `validate_isbn_of` in `IsbnValidatorSpecHelpers` in `spec/support/isbn_validator_spec_helpers.rb`, included for `type: :model` and `type: :form`. In it, check one allowed and one rejected value with `allow_value`, with a `with_message` chain, e.g. `expect(record).not_to allow_value("9780306406158").for(attribute).with_message(@message || "is not a valid ISBN")`. Never check `validators_on`. Use it with `to` only.
- TODO: When to write a custom validator.
- TODO: How to name and lay out validators.
