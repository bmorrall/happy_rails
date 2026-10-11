# Validators setup

Rules: `.github/instructions/happy_validators.instructions.md`

- Set `config.i18n.raise_on_missing_translations = true` in `config/environments/development.rb` and `config/environments/test.rb`, so an error with no message in the locale files raises. Rails generates the line commented out. Uncomment it in each file.
- Write `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`, which adds a `:modified` error unless `value&.has_changes_to_save? == false`. Copy `assets/app/validators/unmodified_validator.rb`.
- Write `PersistedValidator` in `app/validators/persisted_validator.rb`, which adds a `:not_persisted` error unless `value&.persisted?`. Copy `assets/app/validators/persisted_validator.rb`.
- Add the validators' default messages to `config/locales/en.yml` under `en.errors.messages`: `modified: "has unsaved changes"` and `not_persisted: "must be saved"`.
