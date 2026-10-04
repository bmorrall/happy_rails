---
title: ViewComponent
parent: Gems
grand_parent: The Guide
nav_order: 7
---

# ViewComponent

Reusable view code with [ViewComponent](https://viewcomponent.org).

## Setup

Include the route helpers in component specs, in `spec/support/view_component.rb`. Component specs can then build paths, e.g. `post_publication_path(post)`, and use shared matchers that build them, e.g. `have_publish_button_for_post(post)`. See [RSpec: Support files](../rspec/#support-files).

```ruby
# spec/support/view_component.rb
RSpec.configure do |config|
  config.include Rails.application.routes.url_helpers, type: :component
end
```

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
class Posts::CardComponent < ViewComponent::Base
  def initialize(post:, can_update: false)
    @post = post
    @can_update = can_update
  end

  def can_update?
    !!@can_update
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

> **TODO:** Describe how you handle this.

### Matchers for components

Give each component a matcher, named after the component with a `have_` prefix and a `_component` suffix, e.g. `have_posts_publishing_section_component` for `Posts::PublishingSectionComponent`. See [RSpec: Custom matchers](../rspec/#custom-matchers).

The matcher checks that the component is on the page, not how it's built. Match the component's outer element, and an easily identifiable part of it if the component has one, e.g. a `section` with the `post_publishing` class and its `h2` title of "Publishing". Not every component has a title. Pick a part that says which component it is, not a part of what it does. Leave out what's inside, e.g. the form. The component spec checks the inside. A request or feature spec checks a part of it only when it needs to, e.g. that the form publishes the post. The matcher then keeps working when the inside changes, and every spec that renders the page doesn't repeat the component spec.

```ruby
# spec/support/post_spec_helpers.rb
module PostSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :have_posts_publishing_section_component do
    match do |actual|
      expect(actual).to have_css("section.post_publishing h2", text: "Publishing")
    end
  end
end

RSpec.configure do |config|
  # ...
  config.include PostSpecHelpers, type: :component
end
```

Don't check the inside in the matcher.

```ruby
matcher :have_posts_publishing_section_component do
  match do |actual|
    expect(actual).to have_css("section.post_publishing form[action$='/publication'] button", text: "Publish")
  end
end
```

Put the matcher in the module for the component's resource, e.g. `PostSpecHelpers` for a component in `Posts::`, and add component specs to the module's includes. See [RSpec: Where to put matchers](../rspec/#where-to-put-matchers). The component's own spec then checks that it renders with the matcher, so the two can't drift apart. Check the inside of the component in the same spec, alongside the matcher. Use a shared matcher for a part that other specs also check, e.g. `have_publish_button_for_post(post)`, so every spec checks it the same way.

```ruby
RSpec.describe Posts::PublishingSectionComponent, type: :component do
  it "renders the publishing section with a form to publish the post", :aggregate_failures do
    post = build_stubbed(:post)

    render_inline(described_class.new(post: post))

    expect(page).to have_posts_publishing_section_component
    expect(page).to have_publish_button_for_post(post)
  end
end
```
