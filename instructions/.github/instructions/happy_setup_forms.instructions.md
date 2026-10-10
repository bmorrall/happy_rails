---
applyTo: "app/forms/application_form.rb"
---

# Forms setup

- Write `ApplicationForm` in `app/forms/application_form.rb`. Include `ActiveModel::Model`, `ActiveModel::Attributes`, `ActiveModel::Attributes::Normalization` (Rails 8.1 or later) and `ActiveModel::Validations::Callbacks`, take the current user and the params in `initialize(current_user, params = {})`, and keep `current_user` in a private `attr_reader`.
