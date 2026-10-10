---
applyTo: "app/decorators/application_decorator.rb,app/decorators/nil_decorator.rb,app/decorators/concerns/**/*.rb"
---

# Draper setup

- Build `NilDecorator.for(klass)` in `app/decorators/nil_decorator.rb` as a stand-in for the decorator of `klass`, e.g. `NilDecorator.for(User)` for `UserDecorator`. In `for`, decorate a new instance of `klass` and wrap it, e.g. `new(klass.new.decorate)`. Check each method call against that wrapped decorator in `method_missing` and `respond_to_missing?`: return `false` for a `can_` method ending in `?` that it responds to, e.g. `can_update?`, return `h.unknown_value_tag` for any other method it responds to, and raise `NoMethodError` (with `super`) for a method it does not respond to. Include `Draper::ViewHelpers` for `h`, and return `false` from `present?`, `true` from `blank?` and `nil` from `presence`.
- For a paginated collection, write one concern for each paginator that delegates the paginator's methods to the collection, named after the paginator, e.g. `KaminariPagination` in `app/decorators/concerns/kaminari_pagination.rb` with `delegate :current_page, :total_pages, :limit_value, :total_count, :offset_value, :last_page?`.
- With Pundit, build the policy in `ApplicationDecorator` from the view's `policy` helper with `object`, memoise it, and keep the method private, e.g. `def policy = @policy ||= h.policy(object)` under `private`.
- In `ApplicationDecorator`, under a `### Policy ###` comment, delegate the standard Rails action checks to the policy with a `can` prefix, e.g. `delegate :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :policy, prefix: :can`.
