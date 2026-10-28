---
title: Views and Frontend
parent: Testing
nav_order: 10
---

# Views and Frontend

How I test views and helpers.

For the code itself, see [Views and Frontend](../../guide/views/).

You MUST NOT write a view spec. A view spec renders a template on its own, with data you set up by hand, so it can pass while the real page is broken. It also repeats what other specs already check.

Test each part of a page where its logic lives:

- **Templates and partials:** request specs. Each branch in a view the action renders needs at least one example. See [Controllers and Routes: Request specs](../controllers/#request-specs).
- **Components:** component specs. See [ViewComponent: Testing](../gems/view_component/).
- **Decorators:** decorator specs. See [Draper: Testing](../gems/draper/).
- **Helpers:** helper specs.

A field the form only shows to some users is a branch too. In the page's request spec, check it for a persona who can set it and one who can't, e.g. on `GET /posts/:id/edit`, as a Publishing Manager and as an Author. See [Views and Frontend: Fields the user can't set](../../guide/views/#fields-the-user-cant-set).

Check the field with a helper named after it, e.g. `have_featured_field`, that wraps `have_field` and passes Capybara's options through. Use it for both checks, e.g. `to have_featured_field` and `not_to have_featured_field`, or `to have_featured_field(disabled: true)` when the form disables the field. The checks then share one locator. If the field's label changes, the positive check fails, instead of the `not_to` check passing because it looks for a label that's gone. Define the helper at the bottom of the spec file, as in [RSpec: Where to put matchers](../gems/rspec/#where-to-put-matchers).

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id/edit", :aggregate_failures do
    context "as a publishing manager" do
      # ...

      it "shows the featured field" do
        get edit_post_path(draft)

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_featured_field
      end
    end

    context "as a user", "with a post as the author" do
      # ...

      it "does not show the featured field" do
        get edit_post_path(draft)

        expect(response).to have_http_status(:ok)

        expect(response.body).not_to have_featured_field
      end
    end
  end

  def have_featured_field(**options)
    have_field("Featured", **options)
  end
end
```

{: .rant }
> Turn off view specs in the RSpec generator, so `rails generate` doesn't create them.
>
> ```ruby
> # config/application.rb
> config.generators do |g|
>   g.test_framework :rspec, view_specs: false
> end
> ```

## Helpers

Give each helper that builds a simple view element a matcher, so specs check for it the same way everywhere. See [RSpec: Matchers for helpers](../gems/rspec/#matchers-for-helpers).
