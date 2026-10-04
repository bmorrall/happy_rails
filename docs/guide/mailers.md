---
title: Mailers
parent: The Guide
nav_order: 9
---

# Mailers

Sending email.

## Naming and layout

> **TODO:** Describe how you handle this.

## Templates

Don't use decorators or presenters in mailers. A mailer has no request and no signed-in user, so anything that reads them fails. Decorator links also use `_path` helpers, which give relative URLs that break in an email. In a mailer template, use the plain record and your helpers directly, with `_url` helpers for links. Values still look the same as on the page, because the helpers do the formatting. See [Draper: Decorating in controllers](../gems/draper/#decorating-in-controllers).

```erb
<%# app/views/post_mailer/published.html.erb %>
<p><%= link_to @post.title, post_url(@post) %></p>
<p>Published <%= date_tag(@post.published_at) %></p>
```

Never render a page component in a mailer template. Page components take decorated records, build links with `_path` helpers, and rely on the app's stylesheets, which email clients ignore. When several emails repeat the same markup, write a component for email under a `Mailers::` namespace. Give it plain values and full URLs, and style it inline.

```ruby
class Mailers::ButtonComponent < ViewComponent::Base
  def initialize(label:, url:)
    @label = label
    @url = url
  end
end
```

```erb
<%= render Mailers::ButtonComponent.new(label: "Read post", url: post_url(@post)) %>
```

## Previews

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
