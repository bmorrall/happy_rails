# Actions setup

Rules: `.github/instructions/happy_actions.instructions.md`

- Write `ApplicationAction` in `app/actions/application_action.rb`, with a class method `call` that runs `new(...).call` and returns `nil`. Copy `assets/app/actions/application_action.rb`.
- Write `ValidatedCallable` in `app/actions/concerns/validated_callable.rb`, which adds `ActiveModel::Validations` and runs `validate!` before `call`. Copy `assets/app/actions/concerns/validated_callable.rb`.
- Write `NonTransactionalCallable` in `app/actions/concerns/non_transactional_callable.rb`, which raises in the class method `call` when `ActiveRecord::Base.connection.current_transaction.joinable?` and otherwise calls `super`. Copy `assets/app/actions/concerns/non_transactional_callable.rb`.
