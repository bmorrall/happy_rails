---
applyTo: "app/mailers/**/*.rb,app/views/*_mailer/**/*,spec/mailers/**/*.rb"
---

# Mailers

- Never use decorators or presenters in mailers or mailer templates, e.g. `decorates_assigned :post` in `PostMailer`. Use the plain record with helpers, and `_url` helpers for links, e.g. `<%= link_to @post.title, post_url(@post) %>` and `<%= date_tag(@post.published_at) %>` in `app/views/post_mailer/published.html.erb`.
- Never render a page component in a mailer template, e.g. `Posts::CardComponent`. For markup repeated across emails, write a component under a `Mailers::` namespace that takes plain values and full URLs and uses inline styles, e.g. `render Mailers::ButtonComponent.new(label: "Read post", url: post_url(@post))`.
- TODO: How to name and lay out mailers, e.g. `PostMailer`.
- TODO: How to write mailer previews.
- TODO: How to write mailer specs.
