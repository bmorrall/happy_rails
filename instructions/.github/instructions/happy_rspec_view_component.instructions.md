---
applyTo: "spec/components/**/*.rb,spec/support/**/*.rb"
---

# ViewComponent specs

- You MUST NOT tag a component spec with `type: :component` by hand.
- Give each component a matcher named after the component with a `have_` prefix and a `_component` suffix, e.g. `have_posts_publishing_section_component` for `Posts::PublishingSectionComponent`.
- In a component matcher, check only that the component is on the page: its outer element, and an easily identifiable part of it if it has one, e.g. its title in `expect(actual).to have_css("section.post_publishing h2", text: "Publishing")`. You MUST NOT check what is inside, e.g. the form. Leave the inside to the component spec, and to request or feature specs that need it.
- Put a component matcher in the module for the component's resource, e.g. `PostSpecHelpers` in `spec/support/post_spec_helpers.rb` for `Posts::PublishingSectionComponent`, and add `config.include PostSpecHelpers, type: :component` to the module's existing `RSpec.configure` block, next to its request and feature includes. Check the component renders with its matcher in its component spec, e.g. `expect(page).to have_posts_publishing_section_component` after `render_inline`, and check the inside in the same spec, using a shared matcher for a part other specs also check, e.g. `expect(page).to have_publish_button_for_post(post)`.
- TODO: How to write component specs.
