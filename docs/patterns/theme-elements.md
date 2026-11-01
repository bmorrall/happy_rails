---
title: Theme Elements
parent: Patterns
nav_order: 10
---

# Theme Elements

How to build the parts of a theme that every page uses, e.g. buttons, badges and panels, when [templates don't write the theme's classes](../../guide/views/#css-and-assets).

A theme, often based on a template you bought or a CSS framework, has its own markup and classes for each element. A button is `<a class="btn btn-primary">`, and a panel is a `card` with a header and a body. When each template writes that markup itself, the same classes are copied to every page. A small change to the theme then means editing every template, and pages drift apart as some are updated and others are missed.

These patterns put each element in one place, behind a helper or a component, so templates ask for a button or a panel and the theme decides how it looks.

## Keep the theme in one namespace

Put every theme helper and component in one namespace, e.g. `Theme`. The helpers go in `app/helpers/theme/`, and the components in `app/components/theme/`. You can then find every part of the theme in one place, and replace it as a whole.

```
app/
  components/
    theme/
      panel_component.rb
      panel_component.html.erb
  helpers/
    theme/
      badges_helper.rb
      buttons_helper.rb
      panels_helper.rb
```

The name is up to you. A generic name, e.g. `Theme`, means no template changes when you move to a new theme. A name taken from the template, e.g. `Tabler`, says where the markup comes from, and lets two themes sit side by side while you move from one to the other. Whichever you pick, use the same one everywhere.

Rails includes every helper in `app/helpers` in every view, including the ones in folders, so `Theme::ButtonsHelper` needs no setup. Its methods are still global, though. Start each one with `theme_`, e.g. `theme_button`, so it can't clash with a Rails helper, e.g. `button_tag`, and so every call to the theme is easy to search for.

Keep the theme free of the app's records. A theme helper or component takes strings, symbols, URLs and blocks, never a `Post`. It then works on any page, and its previews and specs need no records.

## Helpers for simple elements

When an element is one tag with some content and a few options, write a helper. Name the options after what they mean, e.g. `variant: :primary`, not after the theme's classes. The helper turns them into classes.

```ruby
# app/helpers/theme/buttons_helper.rb
module Theme
  module ButtonsHelper
    BUTTON_CLASSES = {
      primary: "btn btn-primary",
      secondary: "btn btn-outline-secondary",
      danger: "btn btn-danger"
    }.freeze

    def theme_button(name, url, variant: :primary, **options)
      link_to name, url, class: BUTTON_CLASSES.fetch(variant), **options
    end
  end
end
```

```erb
<%# app/views/posts/show.html.erb %>
<%= theme_button "Edit", edit_post_path(@post), variant: :secondary %>
```

`fetch` raises on a variant the theme doesn't have, so a typo fails in your specs instead of rendering an unstyled button.

## Components for elements with slots

When an element has more than one area of content, write a component. A panel has a title, a body, and buttons at the top. A helper can only take one block, but a component can take a slot for each area.

```ruby
# app/components/theme/panel_component.rb
module Theme
  class PanelComponent < ViewComponent::Base
    renders_many :actions

    def initialize(title:)
      @title = title
    end
  end
end
```

```erb
<%# app/components/theme/panel_component.html.erb %>
<section class="card">
  <header class="card-header d-flex align-items-center">
    <h2 class="card-title"><%= @title %></h2>
    <% if actions? %>
      <div class="ms-auto">
        <% actions.each do |action| %>
          <%= action %>
        <% end %>
      </div>
    <% end %>
  </header>
  <div class="card-body">
    <%= content %>
  </div>
</section>
```

## Helpers that render components

Templates can render the component directly, but then some elements are called as helpers and others as components. Instead, give each component a helper that renders it. Templates then use the theme only through `theme_` helpers, and don't need to know which elements are components.

The helper passes its block on to the component, so the template still gets the component and fills its slots.

```ruby
# app/helpers/theme/panels_helper.rb
module Theme
  module PanelsHelper
    def theme_panel(title:, &block)
      render Theme::PanelComponent.new(title:), &block
    end
  end
end
```

```erb
<%# app/views/posts/show.html.erb %>
<%= theme_panel title: @post.title do |panel| %>
  <% panel.with_action do %>
    <%= theme_button "Edit", edit_post_path(@post), variant: :secondary %>
  <% end %>
  <%= markdown_tag(@post.body) %>
<% end %>
```

An element can then start as a helper and become a component when it needs slots, and no template changes. The component spec covers the markup and the slots. The helper spec only checks that the helper renders the component with the arguments it was given.

## Theme elements in other components

A component for the app's own records, e.g. `Posts::CardComponent`, builds its markup from the theme too. Use the same `theme_` helpers as a template, so there's one way to use the theme wherever you are. An element can then still become a component without changing any caller.

Include the theme's helper modules in `ApplicationComponent`, rather than calling them through `helpers`. ViewComponent warns against `helpers`, because it ties the component to the view that renders it. The theme helpers only use `link_to`, `tag` and `render`, which every component has, so they work the same in a component as in a template.

```ruby
# app/components/application_component.rb
class ApplicationComponent < ViewComponent::Base
  include Theme::BadgesHelper
  include Theme::ButtonsHelper
  include Theme::PanelsHelper
end
```

```erb
<%# app/components/posts/card_component.html.erb %>
<%= theme_panel title: @post.title do |panel| %>
  <% if can_update? %>
    <% panel.with_action do %>
      <%= theme_button "Edit", edit_post_path(@post), variant: :secondary %>
    <% end %>
  <% end %>
  <p><%= @post.published_on %></p>
<% end %>
```

Add each new theme helper module to `ApplicationComponent` when you write it. The record goes to `Posts::CardComponent`, and only its values go to the theme. See [ViewComponent: Decorated records](../../guide/gems/view_component/#decorated-records).

## What to avoid

Don't write the theme's classes in a template, e.g. `class="btn btn-primary"`. Every page that does has to change when the theme changes.

Don't pass a record to a theme element, e.g. `theme_panel post: @post`. The theme then knows about posts, and can't be used for anything else. Pass the values it shows instead.
