---
title: ViewComponent
parent: Gems
grand_parent: The Guide
nav_order: 8
---

# ViewComponent

Reusable view code with [ViewComponent](https://viewcomponent.org).

## When to use a component

> **TODO:** Describe how you handle this.

## Naming and layout

> **TODO:** Describe how you handle this.

## Slots and arguments

> **TODO:** Describe how you handle this.

## Decorated records

Pass a component the decorated record, e.g. `post` from `decorates_assigned`, not `@post`. The component then shows each value the same way as the template, e.g. `post.published_on`. See [Draper](../draper/).

A component must work without a request. Previews, component specs, mailers and Turbo Stream broadcasts all render it with no request and no signed-in user. So never call a permission check in a component, e.g. `@post.can_update?`, and never call a decorator method that needs the request, e.g. one that reads `h.current_user` or `h.params`. When a permission toggles part of the component, pass it in as a flag. Name the flag after the check, e.g. `can_update:` for `post.can_update?`, and default it to `false`. Read it through a predicate method with the same name, e.g. `can_update?`, which returns `!!@can_update`. The template checks the permission, and the component only reads the flag. A preview or spec then sets each case directly, and a caller that forgets the flag hides the action rather than showing it.

```ruby
module Posts
  class CardComponent < ViewComponent::Base
    def initialize(post:, can_update: false)
      @post = post
      @can_update = can_update
    end

    def can_update?
      !!@can_update
    end
  end
end
```

```erb
<%# app/components/posts/card_component.html.erb %>
<article>
  <h2><%= @post.link %></h2>
  <p><%= @post.published_on %></p>
  <% if can_update? %>
    <%= @post.edit_link %>
  <% end %>
</article>
```

```erb
<%= render Posts::CardComponent.new(post: post, can_update: post.can_update?) %>
```

## Previews

> **TODO:** Describe how you handle this.

## Testing

See [Testing: ViewComponent](../../../testing/gems/view_component/).
