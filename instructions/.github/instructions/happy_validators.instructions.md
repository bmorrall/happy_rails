---
applyTo: "app/validators/**/*.rb,spec/validators/**/*.rb"
---

# Validators

- Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`.
- Define `UnmodifiedValidator < ActiveModel::EachValidator` to check that a record has no unsaved changes, whether or not it is saved, e.g. `return unless record.respond_to?(:has_changes_to_save?) && record.has_changes_to_save?` then `action.errors.add(attribute, :modified, message: options[:message] || "has unsaved changes")` in `validate_each(action, attribute, record)`.
- Use `unmodified: true` on each record argument of an action that includes `ValidatedCallable`, with `presence: true` when the argument is required, e.g. `validates :post, :publisher, presence: true, unmodified: true` in `Posts::PublishPost`. Never rescue the error it raises.
- TODO: When to write a custom validator.
- TODO: How to name and lay out validators.
- TODO: How to test custom validators.
