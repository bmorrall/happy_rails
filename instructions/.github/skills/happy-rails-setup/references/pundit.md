# Pundit setup

Rules: `.github/instructions/happy_pundit.instructions.md`, `.github/instructions/happy_rspec_pundit.instructions.md`

- Generate `ApplicationPolicy` with `bin/rails generate pundit:install`, and keep its defaults: every permission returns `false`, `new?` calls `create?`, and `edit?` calls `update?`.
- Put Pundit's setup in a `PunditAuthorization` concern in `app/controllers/concerns/pundit_authorization.rb`, with `include Pundit::Authorization` and `after_action :verify_authorized, unless: :devise_controller?` and `after_action :verify_policy_scoped, only: :index` in its `included` block. Rescue failed checks in the concern with `rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized_error`, and in the private `handle_not_authorized_error` method, redirect with an alert to the private `after_not_authorized_error_path` method, which returns `root_path`. Copy `assets/app/controllers/concerns/pundit_authorization.rb`.
- Add `include PunditAuthorization` to `ApplicationController`.
- Give forms Pundit's `policy` and `policy_scope` through a `PunditPolicies` concern in `app/forms/concerns/pundit_policies.rb`. Copy `assets/app/forms/concerns/pundit_policies.rb`. Add `include PunditPolicies` to `ApplicationForm`, after its other `include` lines.
- Load Pundit's matchers in `spec/support/pundit.rb` with `require "pundit/rspec"`. Copy `assets/spec/support/pundit.rb`.
