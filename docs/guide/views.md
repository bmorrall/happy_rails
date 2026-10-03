---
title: Views and Frontend
parent: The Guide
nav_order: 5
---

# Views and Frontend

How pages are rendered and made interactive.

## Templates and partials

> **TODO:** Describe how you handle this.

## Helpers

> **TODO:** Describe how you handle this.

## Forms

> **TODO:** Describe how you handle this.

## Hotwire: Turbo and Stimulus

> **TODO:** Describe how you handle this.

## CSS and assets

> **TODO:** Describe how you handle this.

## Testing

Never write a view spec. A view spec renders a template on its own, with data you set up by hand, so it can pass while the real page is broken. It also repeats what other specs already check.

Test each part of a page where its logic lives:

- **Templates and partials:** request specs. Each branch in a view the action renders needs at least one example. See [Controllers and Routes: Testing](../controllers/#testing).
- **Components:** component specs. See [ViewComponent: Testing](../gems/view_component/#testing).
- **Decorators:** decorator specs. See [Draper: Testing](../gems/draper/#testing).
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
