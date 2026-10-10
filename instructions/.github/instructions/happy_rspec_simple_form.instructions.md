---
applyTo: "spec/requests/**/*.rb,spec/features/**/*.rb,spec/support/**/*.rb"
---

# Simple Form specs

- Never write specs for inputs, e.g. in `spec/inputs`.
- Give each custom select input a matcher named after the input with a `have_` prefix, that wraps `have_select` with the input's type as a class and passes the arguments through, e.g. `def have_comment_select(locator = nil, **options) = have_select(locator, class: "comment_select", **options)` for `CommentSelectInput`. Put it in the module for the input's resource, e.g. `CommentSpecHelpers` in `spec/support/comment_spec_helpers.rb`, included for `type: :request` and `type: :feature`.
- Test a custom input through the request specs for the pages that render it, and check the select and its options with its matcher, one option on each line, e.g. `expect(response.body).to have_comment_select("Featured comment", with_options: ["Great post!"])` and `expect(response.body).to have_comment_select("Featured comment", with_options: ["Thanks for sharing"])` in `describe "GET /posts/:id/edit"`.
- Cover each custom input in at least one feature spec where a persona picks an option and submits the form, e.g. `select "Great post!", from: "Featured comment"` in `scenario "Publishing Manager features a comment"`, then check the saved value, e.g. `expect(page).to have_comment_select("Featured comment", selected: "Great post!")` after editing the post again.
