# Forms setup

Rules: `.github/instructions/happy_forms.instructions.md`

- Write `ApplicationForm` in `app/forms/application_form.rb`. Include `ActiveModel::Model`, `ActiveModel::Attributes`, `ActiveModel::Attributes::Normalization` and `ActiveModel::Validations::Callbacks`, take the current user and the params in `initialize(current_user, params = {})`, and keep `current_user` in a private `attr_reader`. Copy `assets/app/forms/application_form.rb`.
- Before Rails 8.1, leave out `ActiveModel::Attributes::Normalization`, which needs Rails 8.1 or later.
