# Pundit setup

Rules: `.github/instructions/happy_pundit.instructions.md`

- Put Pundit's setup in a `PunditAuthorization` concern in `app/controllers/concerns/pundit_authorization.rb`, with `include Pundit::Authorization` and `after_action :verify_authorized, unless: :devise_controller?` in its `included` block. Rescue failed checks in the concern with `rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized_error`, and in the private `handle_not_authorized_error` method, redirect to the root page with an alert. Copy `assets/app/controllers/concerns/pundit_authorization.rb`.
- Add `include PunditAuthorization` to `ApplicationController`.
- Give forms Pundit's `policy` and `policy_scope` through a `PunditPolicies` concern in `app/forms/concerns/pundit_policies.rb`. Copy `assets/app/forms/concerns/pundit_policies.rb`. Add `include PunditPolicies` to `ApplicationForm`, after its other `include` lines.
- Load Pundit's matchers in `spec/support/pundit.rb` with `require "pundit/rspec"`. Copy `assets/spec/support/pundit.rb`.
