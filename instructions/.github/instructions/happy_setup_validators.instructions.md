---
applyTo: "app/validators/unmodified_validator.rb,config/environments/development.rb,config/environments/test.rb"
---

# Validators setup

- Set `config.i18n.raise_on_missing_translations = true` in `config/environments/development.rb` and `config/environments/test.rb`, so an error with no message in the locale files raises.
- Write `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`, which adds a `:modified` error if `value.has_changes_to_save?`.
