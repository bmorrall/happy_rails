---
title: Views and Frontend
parent: Testing
nav_order: 10
---

# Views and Frontend

How I test views and helpers.

For the code itself, see [Views and Frontend](../../guide/views/).

Never write a view spec. A view spec renders a template on its own, with data you set up by hand, so it can pass while the real page is broken. It also repeats what other specs already check.

Test each part of a page where its logic lives:

- **Templates and partials:** request specs. Each branch in a view the action renders needs at least one example. See [Controllers and Routes: Request specs](../controllers/#request-specs).
- **Components:** component specs. See [ViewComponent: Testing](../gems/view_component/).
- **Decorators:** decorator specs. See [Draper: Testing](../gems/draper/).
- **Helpers:** helper specs.

{: .rant }
> Turn off view specs in the RSpec generator, so `rails generate` doesn't create them.
>
> ```ruby
> # config/application.rb
> config.generators do |g|
>   g.test_framework :rspec, view_specs: false
> end
> ```

## Helpers

Give each helper that builds a simple view element a matcher, so specs check for it the same way everywhere. See [RSpec: Matchers for helpers](../gems/rspec/#matchers-for-helpers).
