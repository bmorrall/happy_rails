---
title: Theme Elements
parent: Patterns
nav_order: 10
---

# Theme Elements

How to build the parts of a theme that every page uses, e.g. buttons, badges and panels, when [templates don't write the theme's classes](../../guide/views/#css-and-assets).

A theme, often based on a template you bought or a CSS framework, has its own markup and classes for each element. A button is `<a class="btn btn-primary">`, and a panel is a `card` with a header and a body. When each template writes that markup itself, the same classes are copied to every page. A small change to the theme then means editing every template, and pages drift apart as some are updated and others are missed.

These patterns put each element in one place, behind a helper or a component, so templates ask for a button or a panel and the theme decides how it looks.

Not every element needs a helper. An element that only one page uses, e.g. a banner on the home page, can keep its classes in that page's template. It becomes a theme element when a second page needs it.

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

## Helpers for layouts

A layout that pages repeat is a theme element too, e.g. a grid of cards, or the spacing around each section of a page. Give it a helper that takes a block. The template fills it, and the theme sets the columns and the gaps.

```ruby
# app/helpers/theme/grids_helper.rb
module Theme
  module GridsHelper
    # From the theme's product-grid.tsx
    GRID_CLASSES = {
      full_width: "row row-cols-2 row-cols-lg-4 g-3",
      with_sidebar: "row row-cols-2 row-cols-lg-3 g-3"
    }.freeze

    def theme_grid(variant: :full_width, **options, &)
      tag.div(class: GRID_CLASSES.fetch(variant), **options, &)
    end
  end
end
```

```erb
<%# app/views/posts/index.html.erb %>
<%= theme_grid do %>
  <% posts.each do |post| %>
    <%= render Posts::CardComponent.new(post:) %>
  <% end %>
<% end %>
```

A page layout with more than one area, e.g. a sidebar and a main column, needs a slot for each area, so it's a component. See [Components for elements with slots](#components-for-elements-with-slots).

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

Include the theme's helper modules in the app's base component class, e.g. `ApplicationComponent`, rather than calling them through `helpers`. ViewComponent warns against `helpers`, because it ties the component to the view that renders it. The theme helpers only use `link_to`, `tag` and `render`, which every component has, so they work the same in a component as in a template.

```ruby
# app/components/application_component.rb
class ApplicationComponent < ViewComponent::Base
  include Theme::BadgesHelper
  include Theme::ButtonsHelper
  include Theme::GridsHelper
  include Theme::PanelsHelper
end
```

Inherit the app's components from the base class, e.g. `Posts::CardComponent < ApplicationComponent`. Keep `ApplicationComponent` for that one job, as `ApplicationController` and `ApplicationRecord` are. When the app has a component for the page shell, e.g. the layout and its menus, give it a name of its own, e.g. `LayoutComponent`.

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

## Specs for theme elements

Give each theme helper a matcher, as for any helper that builds a view element. See [RSpec: Matchers for helpers](../../testing/gems/rspec/#matchers-for-helpers). Put the matchers in the theme's namespace too, e.g. `Theme::ButtonsSpecHelpers` in `spec/support/theme/buttons_spec_helpers.rb`, so they are replaced with the theme.

Find the element by what it is first, e.g. a link and its text. Use the theme's classes only for what nothing else shows, e.g. the variant. The matcher then changes with the helper, in one place.

```ruby
# spec/support/theme/buttons_spec_helpers.rb
module Theme
  module ButtonsSpecHelpers
    BUTTON_CLASSES = {
      primary: "btn-primary",
      secondary: "btn-outline-secondary",
      danger: "btn-danger"
    }.freeze

    def have_theme_button(locator = nil, variant: :primary, **options)
      have_link(locator, class: BUTTON_CLASSES.fetch(variant), **options)
    end
  end
end

RSpec.configure do |config|
  config.include Theme::ButtonsSpecHelpers, type: :helper
  config.include Theme::ButtonsSpecHelpers, type: :request
  config.include Theme::ButtonsSpecHelpers, type: :feature
end
```

```ruby
expect(response.body).to have_theme_button("Edit", variant: :secondary)
```

## The app's layout

The site header, its menus and the footer are not theme elements. They hold the app's own links, e.g. `posts_path`, and its state, e.g. the signed-in user, and the app's layout renders them once. Write their classes in the layout, or in a component outside the theme's namespace, e.g. `HeaderComponent`. Build their parts from the theme's elements, e.g. `theme_button` for the "New post" link.

To tell them apart, ask what the part needs. A theme element takes values and blocks, and works on any page. When a part needs the app's routes, records or the signed-in user, it belongs to the app.

## Porting a theme

When you port a theme you bought, e.g. from React to Rails, copy the markup and classes of the elements that pages share into the theme's helpers and components. A few choices come up along the way.

Name each variant after what it's for, e.g. `variant: :with_sidebar`, so the template says what it gets. To trace a helper back to the theme, name the source file in a comment, as in `Theme::GridsHelper` above.

Port one version of each element. A theme can style one element two ways, e.g. its button component, and a "View all" link with its own copy of the button's classes. Start from the theme's own component, e.g. its button. When the other version differs on purpose, e.g. it's shorter, add an option for it, e.g. `size: :small`. Copying both brings the theme's drift into your app, and templates then have to choose between two primary buttons.

When the app already has theme helpers outside the namespace, e.g. `primary_button` in `ButtonsHelper`, move them one part of the app at a time. The old helper and its `theme_` replacement can live side by side until the last template moves. Then delete the old one.

## What to avoid

Don't write the classes of a shared element in a template, e.g. `class="btn btn-primary"`. Every page that does has to change when the theme changes.

Don't pass a record to a theme element, e.g. `theme_panel post: @post`. The theme then knows about posts, and can't be used for anything else. Pass the values it shows instead.

Don't add an attribute to the theme's markup only so specs can find it, e.g. `data-theme-element="grid"`. Find the element as in [Specs for theme elements](#specs-for-theme-elements).
