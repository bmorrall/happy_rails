---
applyTo: "app/actions/application_action.rb,app/actions/concerns/**/*.rb"
---

# Actions setup

- Write `ApplicationAction` in `app/actions/application_action.rb`, with a class method `call` that runs `new(...).call` and returns `nil`.
- Write `ValidatedCallable` in `app/actions/concerns/validated_callable.rb`, which adds `ActiveModel::Validations` and runs `validate!` before `call`.
- Write `NonTransactionalCallable` in `app/actions/concerns/non_transactional_callable.rb`, which raises in the class method `call` when `ActiveRecord::Base.connection.current_transaction.joinable?` and otherwise calls `super`.
