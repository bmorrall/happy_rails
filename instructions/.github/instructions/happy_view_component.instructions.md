---
applyTo: "app/components/**,spec/components/**/*.rb"
---

# ViewComponent

- Pass a component the decorated record, not the instance variable, e.g. `render Posts::CardComponent.new(post: post)` with `post` from `decorates_assigned`.
- Make every component work without a request, e.g. in a preview, a mailer or a Turbo Stream broadcast. Never call a permission check in a component, e.g. `@post.can_update?`, and never call a decorator method that needs the request, e.g. one that reads `h.current_user` or `h.params`.
- When a permission toggles part of a component, pass it in as a flag named after the check, defaulting to `false`, read it through a predicate method that returns `!!@<flag>`, and set it from the template, e.g. `def initialize(post:, can_update: false)` and `def can_update? = !!@can_update` in `Posts::CardComponent`, with `<% if can_update? %>` in its template, rendered with `Posts::CardComponent.new(post: post, can_update: post.can_update?)`.
- TODO: When to use a component instead of a partial.
- TODO: How to name and lay out components, e.g. `Posts::CommentComponent`.
- TODO: How to pass arguments and use slots.
- TODO: How to write previews.
- TODO: How to write component specs.
