---
applyTo: "app/validators/**/*.rb,spec/validators/**/*.rb"
---

# Validators

- Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`.
- In a custom validator, never skip blank values in `validate_each`, e.g. `return if value.blank?`. Leave them to the caller's `allow_blank:` or `allow_nil:`.
- In a custom validator, add `:invalid` when the value doesn't respond to the method the check calls, e.g. `return record.errors.add(attribute, :invalid, **options) unless value.respond_to?(:example?)`.
- Name the arguments to `validate_each` as Rails does, e.g. `def validate_each(record, attribute, value)`.
- Add a validator's errors with a symbol, never a sentence, e.g. `errors.add(attribute, :modified)`, so the message can come from the locale files.
- Put a validator's default message in `config/locales/en.yml` under `en.errors.messages`, e.g. `modified: "has unsaved changes"`. Pass the validator's `options` to every `errors.add`, e.g. `record.errors.add(attribute, :modified, **options)`. Never pass a default message string.
- Set `config.i18n.raise_on_missing_translations = true` in `config/environments/development.rb` and `config/environments/test.rb`, so an error with no message in the locale files raises.
- `UnmodifiedValidator` adds a `:modified` error if `value.has_changes_to_save?`.
- TODO: When to write a custom validator.
- TODO: How to name and lay out validators.
- TODO: How to test custom validators.
