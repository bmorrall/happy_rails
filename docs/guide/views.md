---
title: Views and Frontend
parent: The Guide
nav_order: 6
---

# Views and Frontend

How pages are rendered and made interactive.

## Templates and partials

Keep templates and partials simple. A template should output values and render other parts of the page, with at most a simple `if` to show or hide part of it, or an `each` to repeat part of it for a list. Choosing between values or formatting them is more than that. Move it, and anything more complex, into a component, a decorator or a helper.

Logic in a template can only be tested through a request spec, which is slow and checks the whole page. A component, decorator or helper has its own spec, so each case is quick to test on its own. The template then reads like the page it renders.

```erb
<%# app/views/posts/show.html.erb %>
<h1><%= @post.title %></h1>
<p><%= post_status(@post) %></p>
```

```ruby
module PostsHelper
  def post_status(post)
    if post.published?
      safe_join(["Published", date_tag(post.published_at)], " ")
    else
      "Draft"
    end
  end
end
```

Don't write the same logic in the template.

```erb
<%# app/views/posts/show.html.erb %>
<h1><%= @post.title %></h1>
<p>
  <% if @post.published? %>
    Published <%= l(@post.published_at.to_date, format: :long) %>
  <% else %>
    Draft
  <% end %>
</p>
```

{: .rant }
> Simple templates also keep your options open. When a template only outputs values and renders other parts, you can move it to a simpler rendering engine later, without first pulling logic out of it.

When you render a partial, pass every value it uses as a named local, e.g. `post: @post`. Never read an instance variable in a partial. The `render` call then shows everything the partial needs, and you can render it from any template, whatever instance variables that template has.

```erb
<%# app/views/posts/show.html.erb %>
<%= render "posts/byline", post: @post %>
```

```erb
<%# app/views/posts/_byline.html.erb %>
<p>By <%= post.author.name %></p>
```

Don't let the partial reach for `@post`.

```erb
<%# app/views/posts/show.html.erb %>
<%= render "posts/byline" %>
```

```erb
<%# app/views/posts/_byline.html.erb %>
<p>By <%= @post.author.name %></p>
```

## Helpers

Format primitive values with a helper, e.g. a date, a time or a boolean. Write one helper for each kind of value, and use it everywhere that value is shown: in templates, partials, other helpers, decorators and components. Every page then shows a date, or a yes or no, the same way, and you can change how they look in one place.

Avoid putting helpers in `ApplicationHelper`. Group related helpers in their own helper file. Name each file `<Things>Helper` after what it covers, in the plural, like the `PostsHelper` that Rails generates for a resource, e.g. `DatesHelper` for dates and times, and `BooleansHelper` for booleans. Each file then stays small, and its helper spec covers one kind of value. Rails includes every helper in `app/helpers` in every view, so you don't lose anything by splitting them up.

Give each helper that builds a simple view element a matcher, so specs check for it the same way everywhere. See [RSpec: Matchers for helpers](../gems/rspec/#matchers-for-helpers).

```ruby
# app/helpers/dates_helper.rb
module DatesHelper
  def date_tag(value)
    time_tag(value.to_date, l(value.to_date, format: :long))
  end

  def datetime_tag(value)
    time_tag(value, l(value, format: :long))
  end
end
```

```ruby
# app/helpers/booleans_helper.rb
module BooleansHelper
  def yes_no_tag(value)
    tag.span(value ? "Yes" : "No")
  end
end
```

```erb
<%# app/views/posts/show.html.erb %>
<p>Updated <%= datetime_tag(@post.updated_at) %></p>
<p>Featured: <%= yes_no_tag(@post.featured?) %></p>
```

Don't format the value in place, e.g. with `l` or `strftime`, even when it's only once.

```erb
<%# app/views/posts/show.html.erb %>
<p>Updated <%= @post.updated_at.strftime("%d/%m/%Y %H:%M") %></p>
<p>Featured: <%= @post.featured? ? "Yes" : "No" %></p>
```

When a value isn't known, e.g. it's `nil`, strongly prefer to show it with an `unknown_value_tag` helper over a blank, a dash or "N/A" written in place. A helper or decorator that shows a value that can be `nil` then returns `unknown_value_tag` for it. Every page shows a missing value the same way, e.g. as a faded em dash. This isn't a hard rule: if your app already has its own way to show a missing value, keep using it. Give it an `aria-label`, so a screen reader says "Unknown" instead of reading out the dash.

```ruby
# app/helpers/unknown_values_helper.rb
module UnknownValuesHelper
  def unknown_value_tag
    tag.span("—", class: "text-muted", aria: { label: "Unknown" })
  end
end
```

## Forms

Prefer to build a form with `form_with`, and pass it a model or a form object as `model:`. `form_with` then works out the URL, the method and the param key from the model, fills each field with the model's value, and lets you show its errors. If the form needs its own attributes or validations, pass a form object instead of the model. See [Forms](../forms/).

If your app uses Simple Form, build forms with `simple_form_for` instead, in the same way. See [Simple Form](../gems/simple_form/).

```erb
<%# app/views/posts/new.html.erb %>
<%= form_with model: @post do |form| %>
  <%= form.label :title %>
  <%= form.text_field :title %>
  <%= form.submit %>
<% end %>
```

```erb
<%# app/views/posts/new.html.erb %>
<%= form_with model: @create_post_form do |form| %>
  <%# ... %>
<% end %>
```

Avoid `form_for` and `form_tag`, which `form_with` replaces. Avoid `form_with` with only a `url:` or a `scope:`, too. You then have to set the URL, the method and each field's value by hand.

```erb
<%# app/views/posts/new.html.erb %>
<%= form_with url: posts_path, scope: :post do |form| %>
  <%= form.label :title %>
  <%= form.text_field :title, value: @post.title %>
  <%= form.submit %>
<% end %>
```

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
