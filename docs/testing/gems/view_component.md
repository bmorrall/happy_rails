---
title: ViewComponent
parent: Gems
grand_parent: Testing
nav_order: 8
---

# ViewComponent

How I test components.

For the code itself, see [ViewComponent](../../../guide/gems/view_component/).

## Setup

rspec-rails doesn't know `spec/components/`, so give component specs a `:component` type in `spec/support/view_component.rb`, as for form specs. Each component spec then gets the type from its folder, with no tag. See [RSpec: Form specs](../rspec/#form-specs).

Include ViewComponent's test helpers in component specs in the same file, for `render_inline`. Include the route helpers too. Component specs can then build paths, e.g. `post_publication_path(post)`, and use shared matchers that build them, e.g. `have_publish_button_for_post(post)`. See [RSpec: Support files](../rspec/#support-files).

```ruby
# spec/support/view_component.rb
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/components/}) do |metadata|
    metadata[:type] ||= :component
  end

  config.include ViewComponent::TestHelpers, type: :component
  config.include Rails.application.routes.url_helpers, type: :component
end
```

Component specs check the rendered HTML with Capybara's matchers, e.g. `have_css`. Add `type: :component` to the Capybara include in `spec/support/capybara.rb`, not to this file. See [RSpec: Capybara matchers](../rspec/#capybara-matchers).

```ruby
# spec/support/capybara.rb
RSpec.configure do |config|
  config.include Capybara::RSpecMatchers, type: :request
  config.include Capybara::RSpecMatchers, type: :feature
  config.include Capybara::RSpecMatchers, type: :component
end
```

## Component specs

> **TODO:** Describe how you handle this.

## Matchers for components

Give each component a matcher, named after the component with a `have_` prefix and a `_component` suffix, e.g. `have_posts_publishing_section_component` for `Posts::PublishingSectionComponent`. See [RSpec: Custom matchers](../rspec/#custom-matchers).

The matcher checks that the component is on the page, not how it's built. Match the component's outer element, and an easily identifiable part of it if the component has one, e.g. a `section` with the `post_publishing` class and its `h2` title of "Publishing". Not every component has a title. Pick a part that says which component it is, not a part of what it does. Leave out what's inside, e.g. the form. The component spec checks the inside. A request or feature spec checks a part of it only when it needs to, e.g. that the form publishes the post. The matcher then keeps working when the inside changes, and every spec that renders the page doesn't repeat the component spec.

```ruby
# spec/support/post_spec_helpers.rb
module PostSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :have_posts_publishing_section_component do
    match do |actual|
      expect(actual).to have_css("section.post_publishing h2", text: "Publishing")
    end
  end
end

RSpec.configure do |config|
  # ...
  config.include PostSpecHelpers, type: :component
end
```

Don't check the inside in the matcher.

```ruby
matcher :have_posts_publishing_section_component do
  match do |actual|
    expect(actual).to have_css("section.post_publishing form[action$='/publication'] button", text: "Publish")
  end
end
```

Put the matcher in the module for the component's resource, e.g. `PostSpecHelpers` for a component in `Posts::`, and add component specs to the module's includes. See [RSpec: Where to put matchers](../rspec/#where-to-put-matchers). The component's own spec then checks that it renders with the matcher, so the two can't drift apart. Check the inside of the component in the same spec, alongside the matcher. Use a shared matcher for a part that other specs also check, e.g. `have_publish_button_for_post(post)`, so every spec checks it the same way.

```ruby
RSpec.describe Posts::PublishingSectionComponent do
  it "renders the publishing section with a form to publish the post", :aggregate_failures do
    post = build_stubbed(:post)

    render_inline(described_class.new(post: post))

    expect(page).to have_posts_publishing_section_component
    expect(page).to have_publish_button_for_post(post)
  end
end
```
