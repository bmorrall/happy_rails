---
applyTo: "app/components/**,spec/components/**/*.rb,spec/support/**/*.rb"
---

# ViewComponent

- Never tag a component spec with `type: :component` by hand.
- Pass a component the decorated record, not the instance variable, e.g. `render Posts::CardComponent.new(post: post)` with `post` from `decorates_assigned`.
- Make every component work without a request, e.g. in a preview, a mailer or a Turbo Stream broadcast. Never call a permission check in a component, e.g. `@post.can_update?`, and never call a decorator method that needs the request, e.g. one that reads `h.current_user` or `h.params`.
- When a permission toggles part of a component, pass it in as a flag named after the check, defaulting to `false`, read it through a predicate method that returns `!!@<flag>`, and set it from the template, e.g. `def initialize(post:, can_update: false)` and `def can_update? = !!@can_update` in `Posts::CardComponent`, with `<% if can_update? %>` in its template, rendered with `Posts::CardComponent.new(post: post, can_update: post.can_update?)`.
- Give each component a matcher named after the component with a `have_` prefix and a `_component` suffix, e.g. `have_posts_publishing_section_component` for `Posts::PublishingSectionComponent`.
- In a component matcher, check only that the component is on the page: its outer element, and an easily identifiable part of it if it has one, e.g. its title in `expect(actual).to have_css("section.post_publishing h2", text: "Publishing")`. Never check what is inside, e.g. the form. Leave the inside to the component spec, and to request or feature specs that need it.
- Put a component matcher in the module for the component's resource, e.g. `PostSpecHelpers` in `spec/support/post_spec_helpers.rb` for `Posts::PublishingSectionComponent`, and add `config.include PostSpecHelpers, type: :component` to the module's existing `RSpec.configure` block, next to its request and feature includes. Check the component renders with its matcher in its component spec, e.g. `expect(page).to have_posts_publishing_section_component` after `render_inline`, and check the inside in the same spec, using a shared matcher for a part other specs also check, e.g. `expect(page).to have_publish_button_for_post(post)`.
- TODO: When to use a component instead of a partial.
- TODO: How to name and lay out components, e.g. `Posts::CommentComponent`.
- TODO: How to pass arguments and use slots.
- TODO: How to write previews.
- TODO: How to write component specs.
