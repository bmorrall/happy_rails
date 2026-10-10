---
applyTo: "app/controllers/application_controller.rb,app/controllers/concerns/pundit_authorization.rb,app/forms/application_form.rb,app/forms/concerns/pundit_policies.rb,spec/support/pundit.rb"
---

# Pundit setup

- Put Pundit's setup in a `PunditAuthorization` concern in `app/controllers/concerns/pundit_authorization.rb`, with `include Pundit::Authorization` and `after_action :verify_authorized, unless: :devise_controller?` in its `included` block. Add `include PunditAuthorization` to `ApplicationController`.
- Rescue failed checks in the `PunditAuthorization` concern with `rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized_error`. In the private `handle_not_authorized_error` method, redirect to the root page with an alert, e.g. `redirect_to root_url, alert: "You are not authorized to perform this action."`.
- Give forms Pundit's `policy` and `policy_scope` through a `PunditPolicies` concern in `app/forms/concerns/pundit_policies.rb`, with private `def policy(class_or_resource) = Pundit.policy!(current_user, class_or_resource)` and `def policy_scope(scope) = Pundit.policy_scope!(current_user, scope)`. Add `include PunditPolicies` to `ApplicationForm`.
- Load Pundit's matchers in `spec/support/pundit.rb` with `require "pundit/rspec"`.
