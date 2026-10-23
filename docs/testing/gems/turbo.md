---
title: Turbo
parent: Gems
grand_parent: Testing
nav_order: 10
---

# Turbo

How I test Turbo broadcasts.

For the code itself, see [Turbo](../../../guide/gems/turbo/).

## Broadcasting

### Action specs

Check that the action broadcasts with the matcher named after the Turbo method it calls, wrapped around the call. `broadcast_replace_to` is checked with `have_broadcasted_replace_to`, and so on for `append`, `prepend`, `update`, `remove`, `before`, `after` and `refresh`. Pass the same records and target as the code does, e.g. `target: comment`.

```ruby
RSpec.describe Posts::ArchivePost do
  describe ".call" do
    it "refreshes the pages that show the post" do
      post = create(:post)

      expect { described_class.call(post) }
        .to have_broadcasted_refresh_to(post)
    end
  end
end
```

```ruby
expect { described_class.call(comment) }
  .to have_broadcasted_replace_to(comment.post, target: comment)
```

For a custom stream action, use `have_broadcasted_action_to`, as Turbo's `broadcast_action_to` does, e.g. `have_broadcasted_action_to(:highlight, comment.post, target: comment)`.

The matchers wrap rspec-rails' `have_broadcasted_to`. They name the stream the way Turbo does, from each record's global ID, and check only the `action` and `target` attributes of the `<turbo-stream>` tag. You MUST NOT match the whole tag, e.g. `.with('<turbo-stream action="refresh"></turbo-stream>')`. Turbo can add other attributes, e.g. `request-id`, or change their order. Leave the rendered content to the view's specs.

Put them in `spec/support/turbo.rb`, and include them in action specs. The loop defines a matcher for each of Turbo's stream actions.

```ruby
# spec/support/turbo.rb
module TurboSpecHelpers
  %i[append prepend replace update remove before after refresh].each do |action|
    define_method(:"have_broadcasted_#{action}_to") do |*streamables, target: nil|
      have_broadcasted_action_to(action, *streamables, target:)
    end
  end

  def have_broadcasted_action_to(action, *streamables, target: nil)
    attributes = [%(action="#{action}")]
    attributes << %(target="#{target.is_a?(String) ? target : dom_id(target)}") if target

    have_broadcasted_to(turbo_stream_name(streamables)).with(a_string_including(*attributes))
  end

  private

  def turbo_stream_name(streamables)
    streamables.map { |streamable| streamable.try(:to_gid_param) || streamable.to_s }.join(":")
  end
end

# ...

RSpec.configure do |config|
  config.include TurboSpecHelpers, type: :action
  # ...
end
```

`have_broadcasted_to` needs Action Cable's `test` adapter in the test environment. New apps set it in `config/cable.yml`.

```yaml
# config/cable.yml
test:
  adapter: test
```

### Feature specs

Write feature specs for the app's features, not for Turbo. Live comments are a feature, so they get a feature spec, e.g. "Live Comments". Turbo updating the comments is how the feature works, so it isn't one. You MUST NOT write a feature or scenario about Turbo, e.g. `RSpec.feature "Turbo Streams"` or `scenario "Turbo updates the comments"`. Name it after what the persona sees, and check that, as for any other step.

```ruby
RSpec.feature "Live Comments" do
  scenario "User sees a comment appear when the Author approves it" do
    # GIVEN I am signed in as a User
    sign_in create(:user)

    # AND a published post has a comment waiting for approval
    author = create(:user)
    published_post = create(:post, status: :published, author:)
    comment = create(:comment, post: published_post, body: "Great post!")

    # WHEN I open the post
    visit post_path(published_post)
    wait_for_turbo

    # THEN I don't see the comment
    expect(page).not_to have_css("##{dom_id(comment)}")

    # WHEN the Author approves the comment
    using_session(:author) do
      sign_in author
      visit post_path(published_post)
      within_comment(comment) do
        click_button "Approve"
      end
    end

    # THEN I see the comment without reloading the page
    within_comment(comment) do
      expect(page).to have_text("Great post!")
    end
  end
end
```

### Waiting for Turbo

A step that runs before Turbo has started on the page is flaky. Turbo might not handle a click yet, so the browser loads the whole page instead. Or the page might not be listening for broadcasts yet, so it misses the update.

Before a step that Turbo updates in place, call `wait_for_turbo`, e.g. after `visit` in the scenario above. It waits until Turbo has started, and every stream on the page, e.g. from `turbo_stream_from`, is connected. Put it in `spec/support/turbo.rb` too, and include it only in feature specs.

```ruby
# spec/support/turbo.rb
# ...

module TurboFeatureSpecHelpers
  def wait_for_turbo
    page.document.synchronize do
      next if page.evaluate_script("window.Turbo !== undefined")

      raise Capybara::ExpectationNotMet, "Turbo has not started on the page"
    end

    expect(page).to have_no_css("turbo-cable-stream-source:not([connected])", visible: :all)
  end
end

RSpec.configure do |config|
  # ...
  config.include TurboFeatureSpecHelpers, type: :feature
end
```
