---
applyTo: "spec/actions/**/*.rb,spec/features/**/*.rb"
---

# Turbo specs

- In action specs, check a broadcast with the matcher named after the Turbo method the action calls, around the call, passing the same records and target, e.g. `expect { described_class.call(post) }.to have_broadcasted_refresh_to(post)` for `broadcast_refresh_to`, or `have_broadcasted_replace_to(comment.post, target: comment)` for `broadcast_replace_to`. Use `have_broadcasted_action_to` for a custom stream action, e.g. `have_broadcasted_action_to(:highlight, comment.post, target: comment)`. You MUST NOT match the whole `<turbo-stream>` tag, e.g. `.with('<turbo-stream action="refresh"></turbo-stream>')`.
- Write feature specs for the app's features, not for Turbo, e.g. `RSpec.feature "Live Comments"`. You MUST NOT write a feature or scenario about Turbo, e.g. `RSpec.feature "Turbo Streams"` or `scenario "Turbo updates the comments"`. Check what the persona sees, e.g. `within_comment(comment) { expect(page).to have_text("Great post!") }`.
- In feature specs, call `wait_for_turbo` before a step that Turbo updates in place, e.g. after `visit post_path(published_post)` and before the Author approves the comment.
