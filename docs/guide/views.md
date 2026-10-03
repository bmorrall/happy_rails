---
title: Views and Frontend
parent: The Guide
nav_order: 5
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
      "Published #{l(post.published_at.to_date, format: :long)}"
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
