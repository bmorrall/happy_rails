# Draper setup

Rules: `.github/instructions/happy_draper.instructions.md`

- Build `NilDecorator.for(klass)` in `app/decorators/nil_decorator.rb` as a stand-in for the decorator of `klass`, e.g. `NilDecorator.for(User)` for `UserDecorator`. Copy `assets/app/decorators/nil_decorator.rb`. `for` decorates a new instance of `klass` and wraps it, and each method call is checked against that decorator: a `can_` method ending in `?` returns `false`, any other method it responds to returns `h.unknown_value_tag`, and a method it does not respond to raises `NoMethodError`. It is never `present?`.
- With Pundit, build the policy in `ApplicationDecorator` from the view's `policy` helper with `object`, memoise it, and keep the method private. Under a `### Policy ###` comment, delegate the standard Rails action checks to the policy with a `can` prefix. Copy `assets/app/decorators/application_decorator.rb`, or add its parts to the existing file.
