# Validators setup

Rules: `.github/instructions/happy_validators.instructions.md`

- Set `config.i18n.raise_on_missing_translations = true` in `config/environments/development.rb` and `config/environments/test.rb`, so an error with no message in the locale files raises. Rails generates the line commented out. Uncomment it in each file.
- Write `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`, which adds a `:modified` error if `value.has_changes_to_save?`. Copy `assets/app/validators/unmodified_validator.rb`.
- Add the validator's default message to `config/locales/en.yml` under `en.errors.messages`, e.g. `modified: "has unsaved changes"`.
