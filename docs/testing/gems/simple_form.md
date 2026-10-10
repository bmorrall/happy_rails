---
title: Simple Form
parent: Gems
grand_parent: Testing
nav_order: 7
---

# Simple Form

How I test form inputs built with Simple Form.

For the code itself, see [Simple Form](../../../guide/gems/simple_form/).

## Input specs

Don't write specs for inputs. An input spec has to build a form builder and a view by hand, like a view spec, so it can pass while the real form is broken. See [Testing: Views and Frontend](../../views/).

## Matchers

Give each custom select input a matcher, named after the input with a `have_` prefix, e.g. `have_comment_select` for `CommentSelectInput`. Simple Form adds the input's type as a class on the select, e.g. `comment_select`. Wrap `have_select` with that class, and pass the arguments through, so the matcher takes every option `have_select` does, e.g. `selected:`, `with_options:` or `name:`. Specs then check that the field is built with the custom input, not a plain select. See [RSpec: Custom matchers](../rspec/#custom-matchers).

Put the matcher in the module for the input's resource, e.g. `CommentSpecHelpers` in `spec/support/comment_spec_helpers.rb`, and include it in request specs and feature specs.

```ruby
# spec/support/comment_spec_helpers.rb
module CommentSpecHelpers
  def have_comment_select(locator = nil, **options)
    have_select(locator, class: "comment_select", **options)
  end
end

RSpec.configure do |config|
  config.include CommentSpecHelpers, type: :request
  config.include CommentSpecHelpers, type: :feature
end
```

## Request specs

Test a custom input through the request specs for the pages that render it. Check the select and its options with its matcher, e.g. that it offers each comment by its `to_label`. Check one option on each line. See [RSpec: Capybara matchers](../rspec/#capybara-matchers).

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id/edit", :aggregate_failures do
    it "lists the comments to feature" do
      post = create(:post)
      create(:comment, post: post, body: "Great post!")
      create(:comment, post: post, body: "Thanks for sharing")

      get edit_post_path(post)

      expect(response.body).to have_comment_select("Featured comment", with_options: ["Great post!"])
      expect(response.body).to have_comment_select("Featured comment", with_options: ["Thanks for sharing"])
    end
  end
end
```

## Feature specs

Also cover each custom input in at least one feature spec, where a persona picks an option and submits the form. Only a browser shows that the select sends the right value, and that the form saves it. See [RSpec: Feature specs](../rspec/#feature-specs).

```ruby
RSpec.feature "Post Editing" do
  scenario "Publishing Manager features a comment" do
    # ...

    # WHEN I pick a comment to feature
    select "Great post!", from: "Featured comment"
    click_button "Update Post"

    # AND I edit the post again
    click_link "Edit"

    # THEN I see the comment I picked
    expect(page).to have_comment_select("Featured comment", selected: "Great post!")
  end
end
```
