---
applyTo: "app/validators/**/*.rb,spec/validators/**/*.rb"
---

# Validators

- Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`.
- In a custom validator, never skip blank values in `validate_each`, e.g. `return if value.blank?`. Leave them to the caller's `allow_blank:` or `allow_nil:`.
- Add a validator's errors with a symbol, never a sentence, e.g. `errors.add(attribute, :modified)`, so the message can come from the locale files.
- When the app uses I18n, put a validator's default message in `config/locales/en.yml` under `en.errors.messages`, e.g. `example: "is not an example"`. Pass only the caller's message, e.g. `**options.slice(:message)`, never a default string.
- `UnmodifiedValidator` adds a `:modified` error if `record.respond_to?(:has_changes_to_save?) && record.has_changes_to_save?`.
- TODO: When to write a custom validator.
- TODO: How to name and lay out validators.
- TODO: How to test custom validators.
