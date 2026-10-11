---
applyTo: "app/validators/**/*.rb,app/models/**/*.rb,app/forms/**/*.rb"
---

# Validators

- Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`.
- Give each attribute one `validates` call with every validator it needs, e.g. `validates :title, presence: true, length: { maximum: 100, allow_blank: true }`. You MUST NOT split an attribute's validators across several calls, e.g. `validates :title, presence: true` then `validates :title, length: { maximum: 100 }`.
- Name the arguments to `validate_each` as Rails does, e.g. `def validate_each(record, attribute, value)`.
- Name a validator after the check it makes, not the kind of value it checks, and end the name with `Format` when the check matches a pattern, e.g. `PhoneNumberFormatValidator` with `phone_number_format: { allow_blank: true }`, not `PhoneNumberValidator` with `phone_number: true`. Name a validator for a record's state after the state, e.g. `UnmodifiedValidator`.
- In a custom validator, you MUST NOT skip blank values in `validate_each`, e.g. `return if value.blank?`. Leave them to the caller's `allow_blank:` or `allow_nil:`.
- You MUST NOT raise in a custom validator on a blank value or a value of another kind. Fail it with the validator's own error, as Rails' validators do, e.g. `return if valid_isbn?(value.to_s)` in `IsbnFormatValidator` or `return if value&.persisted?` in `PersistedValidator`.
- When matching a pattern is the whole rule, inherit from `ActiveModel::Validations::FormatValidator` and set the pattern and a default message symbol in `initialize`, e.g. `super(options.merge(with: UUID_FORMAT).reverse_merge(message: :invalid_uuid))` in `UuidFormatValidator`, with `invalid_uuid: "is not a valid UUID"` in `en.errors.messages`. When a value also needs another check, e.g. an ISBN's check digit, write an `ActiveModel::EachValidator` instead, still named with `Format`, e.g. `IsbnFormatValidator`.
- Add a validator's errors with a symbol, not a sentence, e.g. `errors.add(attribute, :modified)`, so the message can come from the locale files.
- Put a validator's default message in `config/locales/en.yml` under `en.errors.messages`, e.g. `modified: "has unsaved changes"`. Pass the validator's `options` to every `errors.add`, e.g. `record.errors.add(attribute, :modified, **options)`. You MUST NOT pass a default message string.
- TODO: When to write a custom validator.
