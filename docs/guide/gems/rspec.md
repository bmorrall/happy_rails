---
title: RSpec and FactoryBot
parent: Gems
grand_parent: The Guide
nav_order: 5
---

# RSpec and FactoryBot

Tests with [RSpec](https://rspec.info) and [FactoryBot](https://github.com/thoughtbot/factory_bot).

## Setup

### Support files

Load every file in `spec/support` from `rails_helper.rb`. The line is in the file that `rails generate rspec:install` creates, commented out. Uncomment it.

```ruby
# spec/rails_helper.rb
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }
```

Put spec setup in `spec/support`, not in `rails_helper.rb`, with one file for each gem or concern, named after it, e.g. `spec/support/factory_bot.rb` and `spec/support/devise.rb`. Each file calls `RSpec.configure` for its own setup. `rails_helper.rb` then stays as Rails generated it, and you can find a gem's spec setup by its name. When you remove a gem, delete its file.

```ruby
# spec/support/factory_bot.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

```ruby
# spec/support/devise.rb
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :feature
end
```

### Capybara matchers

Include `Capybara::RSpecMatchers` in request specs and feature specs, in `spec/support/capybara.rb`. Request specs can then check the HTML in a response with the same matchers as feature specs, e.g. `have_link` or `have_field`. A matcher checks an element and its text, which `include` can't do.

Prefer a matcher for the element over `have_content` or `include`, in request specs and feature specs, e.g. `have_link`, `have_button`, `have_field`, `have_select`, or `have_css` with `text:`. `have_content` and `include` pass when the text is anywhere on the page, e.g. in the flash or the page title, so they can pass when the element you meant is missing. `include` also matches the raw HTML, so it can match text inside an attribute.

```ruby
# spec/support/capybara.rb
RSpec.configure do |config|
  config.include Capybara::RSpecMatchers, type: :request
  config.include Capybara::RSpecMatchers, type: :feature
end
```

```ruby
RSpec.describe "Posts" do
  describe "GET /posts" do
    it "links to each post" do
      post = create(:post, title: "Hello World")

      get posts_path

      expect(response.body).to have_link("Hello World", href: post_path(post))
    end
  end
end
```

Don't check for the text alone.

```ruby
expect(response.body).to include("Hello World")
```

When you check a select's options with `with_options:`, check one option on each line. A failure then names the option that's missing. With every option in one list, the failure only says the list didn't match.

```ruby
expect(response.body).to have_select("Status", with_options: ["Draft"])
expect(response.body).to have_select("Status", with_options: ["Published"])
```

Don't check them all in one line.

```ruby
expect(response.body).to have_select("Status", with_options: ["Draft", "Published"])
```

## Spec types

### Form specs

rspec-rails gives a spec its type from its folder, e.g. `type: :model` for `spec/models/`, but it doesn't know `spec/forms/`. Give form specs a `:form` type in `spec/support/forms.rb`, so setup can be included for them by type, like every other spec type. Each form spec then gets the type from its folder, with no tag.

```ruby
# spec/support/forms.rb
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/forms/}) do |metadata|
    metadata[:type] ||= :form
  end
end
```

`||=` keeps a type that a spec sets itself. Include setup for form specs with `type: :form`, e.g. `config.include Shoulda::Matchers::ActiveModel, type: :form`. See [Shoulda Matchers: Validations](../shoulda_matchers/#validations).

> **TODO:** Describe how you handle the rest of this.

## Layout and naming

> **TODO:** Describe how you handle this.

## Factories

> **TODO:** Describe how you handle this.

## Traits

> **TODO:** Describe how you handle this.

### Persona traits

Give the user factory one trait for each role on the whole app, named after the role, e.g. `:app_admin`, `:publishing_manager` and `:copy_editor`. Use a trait for a flag on the user too, e.g. `:employee`. Define the traits in rank order. A plain `create(:user)` is the User persona, with no role. See [Principles: Personas](../../principles/#personas).

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password" }

    trait :app_admin do
      role { :app_admin }
    end

    trait :publishing_manager do
      role { :publishing_manager }
    end

    trait :copy_editor do
      role { :copy_editor }
    end
  end
end
```

Don't add a trait for a role on a record, e.g. the Author of a post. Build a plain user, then give it the role on the record, e.g. `create(:post, author: user)`. Then the spec shows how the user gets access to that record. For a persona with more than one role, build the user with the trait for the whole-app role, then give it the role on the record.

## Request specs

Write a request spec for every controller. See [Controllers and Routes: Request specs](../../controllers/#request-specs) for where to put it and how to lay out its `describe` blocks.

### Personas

Write a context for the personas each action needs, as described in [Principles: Personas](../../principles/#personas).

Only write persona contexts for actions where access depends on who the user is. Some actions don't check a user at all, e.g. an API that authenticates with a shared token, or a callback from another service. Leave out the persona contexts for these. Write a context for each way the request can be authenticated instead, e.g. `"with an access token"`, `"with an invalid access token"` and `"without an access token"`. See [Controllers and Routes: Authentication](../../controllers/#authentication).

```ruby
RSpec.describe "Api::V1::Posts" do
  describe "GET /api/v1/posts", :aggregate_failures do
    context "with an access token" do
      let(:headers) { { "Authorization" => "Bearer #{Rails.application.credentials.api_token}" } }

      it "responds with ok" do
        get api_v1_posts_path, headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid access token" do
      let(:headers) { { "Authorization" => "Bearer invalid" } }

      it "responds with unauthorized" do
        get api_v1_posts_path, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "without an access token" do
      it "responds with unauthorized" do
        get api_v1_posts_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

Write one `context` for each persona whose role plays a part in the action, and for the User and the Guest. Put them in rank order, with the Guest last. Leave out a persona whose role plays no part in the action, e.g. the Copy Editor and the Author in a spec for publishing a post. Neither role has anything to do with publishing, so they get the same answer as the User. The policy spec covers them too.

Name the context after the persona's role, e.g. `"as a publishing manager"`, so the reader can tell what it's for. Use `"when not signed in"` for the Guest. Keep `"as a"` for personas, and name other contexts another way, e.g. `"with a Turbo Stream"`. For a role on the record under test, use "the", e.g. `"as the author"` of the post the request acts on.

For a persona with more than one role, name each role, highest first, e.g. `"as a copy editor as the author"`.

Each persona context implies the record it acts on. For a role on a record, it's the record the persona holds the role on, e.g. an Author acts on a post they wrote. When a context uses a different record, describe that record in a second argument to `context`, e.g. `context "as an author", "with a post written by another user"`. RSpec joins the two into one description.

Set up the persona inside its context, as a signed-in `user`. Build the user with a [persona trait](#persona-traits) for a role on the whole app, or give it the role on the record. Define the `user` and the records the context needs inside the context, not in the `describe` block above it. Don't define a `let` for each persona, e.g. `let(:author)`. Then every context reads on its own, in the same way, and shows how the user gets their access.

You can give the user a person's name, e.g. Jane Tester, if it makes the spec easier to read. The context name must still give the role.

```ruby
RSpec.describe "Posts::Publications" do
  describe "POST /posts/:post_id/publication", :aggregate_failures do
    context "as an app admin" do
      let(:user) { create(:user, :app_admin) }
      let(:draft) { create(:post) }

      before { sign_in user }

      it "publishes the post" do
        post post_publication_path(draft)
        expect(draft.reload).to be_published
      end
    end

    context "as a publishing manager" do
      let(:user) { create(:user, :publishing_manager) }
      let(:draft) { create(:post) }

      before { sign_in user }

      it "publishes the post" do
        post post_publication_path(draft)
        expect(draft.reload).to be_published
      end
    end

    context "as a user" do
      let(:user) { create(:user) }
      let(:draft) { create(:post) }

      before { sign_in user }

      it "does not publish the post" do
        post post_publication_path(draft)
        expect(draft.reload).not_to be_published
      end
    end

    context "when not signed in" do
      let(:draft) { create(:post) }

      it "does not publish the post" do
        post post_publication_path(draft)
        expect(draft.reload).not_to be_published
      end
    end
  end
end
```

An Author may update a post they wrote, but not someone else's. The second context is still an Author, with a post of their own, so it's `"as an author"`, not `"as the author"`. It acts on another user's post. The User and Guest contexts are left out to keep the example short.

```ruby
RSpec.describe "Posts" do
  describe "PATCH /posts/:id", :aggregate_failures do
    context "as the author" do
      let(:user) { create(:user) }
      let(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "updates the post" do
        patch post_path(draft), params: { post: { title: "New title" } }
        expect(draft.reload.title).to eq("New title")
      end
    end

    context "as an author", "with a post written by another user" do
      let(:user) { create(:user) }
      let(:draft) { create(:post) }

      before do
        create(:post, author: user)
        sign_in user
      end

      it "does not update the post" do
        patch post_path(draft), params: { post: { title: "New title" } }
        expect(draft.reload.title).not_to eq("New title")
      end
    end
  end
end
```

### Responses

Check the response of every request. When the action responds with a page or data, check the status with `have_http_status`, e.g. `expect(response).to have_http_status(:ok)`. Leave a blank line above and below it, so the status stands apart from the request and from the checks on the body.

When the action redirects, check where it redirects to with `redirect_to`, e.g. `expect(response).to redirect_to(post_path(draft))`. On the next line, check the flash. Compare the whole flash with a hash, e.g. `expect(flash.to_hash).to match("notice" => "Post was updated.")`, rather than checking one key. If the action sets any other flash, e.g. an `alert` as well as the `notice`, the spec fails and the failure message shows it.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id", :aggregate_failures do
    context "as the author" do
      let(:user) { create(:user) }
      let(:draft) { create(:post, author: user, title: "Hello World") }

      before { sign_in user }

      it "shows the post" do
        get post_path(draft)

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_css("h1", text: "Hello World")
      end
    end
  end

  describe "PATCH /posts/:id", :aggregate_failures do
    context "as the author" do
      let(:user) { create(:user) }
      let(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "updates the post" do
        expect {
          patch post_path(draft), params: { post: { title: "New title" } }
        }.to change { draft.reload.title }.to("New title")

        expect(response).to redirect_to(post_path(draft))
        expect(flash.to_hash).to match("notice" => "Post was updated.")
      end

      it "shows the form again with a blank title" do
        expect {
          patch post_path(draft), params: { post: { title: "" } }
        }.not_to change { draft.reload.title }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

### Several checks per request

Request specs are slow, because each one goes through routing, the controller and the views. Make one request in each example, and check as much as you can about it there: the records it changed, the status or redirect, the flash and the body. Don't repeat the same request in several examples, each with one check.

Tag each action's `describe` block with `:aggregate_failures`, e.g. `describe "POST /posts", :aggregate_failures do`. RSpec then runs all the checks in an example and reports every one that fails, not only the first.

Wrap the request in `expect { }.to change` when it changes a record, e.g. `change(Post, :count).by(1)` or `change { draft.reload.title }`. The spec then shows what the request changed, in the same step as the request. When the request must not change anything, use `not_to change`.

```ruby
RSpec.describe "Posts" do
  describe "POST /posts", :aggregate_failures do
    context "as a user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "creates the post" do
        expect {
          post posts_path, params: { post: { title: "Hello World" } }
        }.to change(Post, :count).by(1)

        expect(response).to redirect_to(post_path(Post.last))
        expect(flash.to_hash).to match("notice" => "Post was created.")
      end

      it "shows the form again with a blank title" do
        expect {
          post posts_path, params: { post: { title: "" } }
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

## Feature specs

Feature specs describe the user stories of the app. Each one shows a persona using a feature from start to finish.

Write at least one feature spec for every controller that serves pages, so that its scenarios cover the happy path of every HTML route. See [Controllers and Routes: Feature specs](../../controllers/#feature-specs) for which routes to cover.

Use `RSpec.feature` and name it after the feature under test, e.g. `RSpec.feature "Post Publishing"`. Write each example as a `scenario`.

Start each scenario's name with the persona carrying out the task, then say what they want to achieve, e.g. `scenario "Publishing Manager publishes a post"`. Order the scenarios by persona rank, as in [Principles: Personas](../../principles/#personas).

Write scenarios for what a persona can do, not for what they can't. Request specs and policy specs already cover the actions a persona isn't allowed to take. Only add a scenario for something a persona can't do when it guards against a regression, e.g. a bug that let them do it before, or when the action is critical, e.g. a Guest must never see a draft post.

Carry out several actions in one scenario. Request specs already test each request on its own, and feature specs are slow to run. A scenario that takes a persona through a whole task shows how the parts of the app work together.

Put a `GIVEN`, `WHEN` or `THEN` comment above each step, so the scenario reads as a user story. Write the comments in the first person, as the persona describing the situation and what they do, e.g. `# GIVEN I am signed in as a Publishing Manager`. `GIVEN` sets the scene, `WHEN` is what the persona does, and `THEN` is what they see. When two steps of the same type follow each other, start the second with `AND`. Leave a blank line before each comment, so each step stands apart. A scenario can go through `WHEN` and `THEN` more than once. Keep the `GIVEN` steps together at the start. The exception is a mocked response, which can have its own `GIVEN` just before the step that needs it, e.g. `# GIVEN the newsletter service accepts the post` before `# WHEN I publish it`.

```ruby
RSpec.feature "Post Publishing" do
  scenario "Publishing Manager publishes a post" do
    # GIVEN I am signed in as a Publishing Manager
    user = create(:user, :publishing_manager)
    sign_in user

    # AND there is a draft post
    create(:post, title: "Hello World")

    # WHEN I open the post from the list
    visit posts_path
    click_link "Hello World"

    # AND I publish it
    click_button "Publish"

    # THEN I see that it was published
    expect(page).to have_css(".notice", text: "Post was published.")

    # WHEN I visit the home page
    visit root_path

    # THEN I see the post listed
    expect(page).to have_link("Hello World")
  end
end
```

### API endpoints

Feature specs can cover an API too. Each scenario shows a client using the API for a task from start to finish, the same as a persona using the pages.

Make the requests through an `ActionDispatch::Integration::Session` named `client`, e.g. `client.post` and `client.response`. The client has its own cookies and headers, apart from the browser session, so it sees the API the way a real client does. Write the scenarios and the `GIVEN`, `WHEN` and `THEN` comments the same way as for pages. When the access token belongs to a user, start the scenario's name with the persona. When it doesn't, start with the client, e.g. `scenario "API client writes a post"`.

Authenticate the way the client does. When the API takes an access token, send the token in the request headers. Don't sign the user in with `sign_in`. The API doesn't use the session, so a spec that signs in could pass even when the token check is broken.

Check that every response matches the pattern you expect: the status, and the shape of the body. Use `match` with RSpec's composable matchers for values the spec can't know in advance, e.g. `an_instance_of(Integer)` for a new ID. A client depends on the shape of each response, so the spec should catch a field that goes missing or changes type.

Take the data for each request from the response before it, e.g. the ID of the post you just created. Don't look the record up in the database, or reuse the record you built with a factory. Then the scenario shows that a client can follow the API from one step to the next, with only what the API gives back.

```ruby
RSpec.feature "Post API" do
  scenario "API client writes a post" do
    # GIVEN I have an access token
    client = ActionDispatch::Integration::Session.new(Rails.application)
    headers = { "Authorization" => "Bearer #{Rails.application.credentials.api_token}" }

    # WHEN I create a post
    client.post api_v1_posts_path, params: { post: { title: "Hello World" } }, headers: headers, as: :json

    # THEN I get the new post back
    expect(client.response).to have_http_status(:created)
    expect(client.response.parsed_body).to match(
      "id" => an_instance_of(Integer),
      "title" => "Hello World"
    )

    # WHEN I fetch the post with the ID I was given
    post_id = client.response.parsed_body["id"]
    client.get api_v1_post_path(post_id), headers: headers

    # THEN I get the same post
    expect(client.response).to have_http_status(:ok)
    expect(client.response.parsed_body).to match(
      "id" => post_id,
      "title" => "Hello World"
    )
  end
end
```

## Custom matchers

When specs look for the same element on more than one page, e.g. a banner or a button, write a custom matcher for it. Name the matcher after what it finds. The specs then read like the page, and when the markup changes, you fix it in one place.

Always write a custom matcher when one spec checks that an element is there and another checks that it isn't, even on the same page. Use the same matcher for both, with `to` and `not_to`. If the two checks differ, the absence check can pass while the element is still there, e.g. when it looks for different text or a different tag. When the markup changes, the presence check fails and gets fixed, but the absence check keeps passing and no longer checks anything.

```ruby
expect(response.body).to have_publish_button_for_post(draft)
expect(response.body).not_to have_publish_button_for_post(published_post)
```

Don't write the two checks separately.

```ruby
expect(response.body).to have_button("Publish")
expect(response.body).not_to have_css("form[action='#{post_publication_path(published_post)}']")
```

A generic matcher takes no arguments, e.g. `have_welcome_new_author_banner`. A matcher for one record takes the record and ends in `_for_<resource>`, e.g. `have_publish_button_for_post(post)`. The name then says which record the element belongs to.

Define a matcher with `matcher`. Every matcher must work with both `to` and `not_to`, with as little code as it needs. Check the element with a Capybara matcher in its `match` block. When the matcher checks one thing, `match` is all it needs. RSpec runs the same block for `not_to`, and flips the result.

```ruby
matcher :have_publish_button_for_post do |post|
  match do |actual|
    expect(actual).to have_css("form[action='#{post_publication_path(post)}'] button", text: "Publish")
  end
end
```

When a matcher only narrows one Capybara matcher, e.g. adds a filter, write it as a method that returns that Capybara matcher, and pass its arguments through. The matcher then takes every option the Capybara matcher does, e.g. `selected:` or `name:`, and `not_to` and its failure messages come from Capybara. Use `matcher` when the matcher checks more than one thing, or builds its own selector.

```ruby
def have_comment_select(locator = nil, **options)
  have_select(locator, class: "comment_select", **options)
end
```

```ruby
expect(page).to have_comment_select("Featured comment", selected: "Great post!")
```

### Composing matchers

Build a complex matcher from simpler ones. Combine them with `and` when the element has more than one part to check, e.g. the banner's heading and its link. Define each part as a private method inside the matcher, with a `have_` prefix and named after what the part is, e.g. `have_welcome_heading` and `have_first_post_link`. The `match` block then reads as a list of parts, and the negated check uses the same parts. Never name a part after one of Capybara's matchers, e.g. `have_link` or `have_title`. The part would then call itself instead of Capybara's matcher, and loop until the stack overflows.

RSpec can't negate a matcher combined with `and`, so `not_to` would raise an error. Add a `match_when_negated` block, with one `expect(actual).not_to` for each part, so `not_to` checks that every part is gone.

Pass `notify_expectation_failures: true` to both blocks, so a failure shows the message from the Capybara matcher that failed. Only pass it when the matcher has both blocks. A matcher with only `match` uses that block for `not_to` too, and flips the result. The option stops RSpec from turning a failure inside `match` into `false`. So when the element is missing, as `not_to` wants, the failure is raised and the spec fails.

```ruby
matcher :have_welcome_new_author_banner do
  match(notify_expectation_failures: true) do |actual|
    expect(actual).to have_welcome_heading.and have_first_post_link
  end

  match_when_negated(notify_expectation_failures: true) do |actual|
    expect(actual).not_to have_welcome_heading
    expect(actual).not_to have_first_post_link
  end

  private

  def have_welcome_heading
    have_css("h2", text: "Welcome, new author")
  end

  def have_first_post_link
    have_link("Write your first post", href: new_post_path)
  end
end
```

```ruby
expect(page).to have_welcome_new_author_banner
expect(page).not_to have_welcome_new_author_banner
```

### Where to put matchers

When only one spec file uses a matcher, define it at the bottom of that file, inside the top-level `describe` block, after the examples. `matcher` then defines it for that file's specs only, next to the specs that use it.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts" do
    # ...
  end

  matcher :have_welcome_new_author_banner do
    # ...
  end
end
```

When more than one spec file uses a matcher, move it to a module in `spec/support`. Extend the module with `RSpec::Matchers::DSL` when it defines matchers with `matcher`, and include it in every spec type that checks the element, e.g. request specs and feature specs. Keep all the includes for a module in its own file, in one `RSpec.configure` block. When a gem's specs need the module too, add their type to the same block, e.g. `type: :component` for ViewComponent. See [Support files](#support-files).

Keep the shared spec code for a resource together, in one module named after the resource with a `SpecHelpers` suffix, e.g. `PostSpecHelpers` in `spec/support/post_spec_helpers.rb`. Put the resource's matchers in it. You then find everything the specs share about posts in one file. The suffix keeps it apart from the app's own helpers, e.g. `PostsHelper` in `app/helpers`. Name a module for generic matchers after what they cover, e.g. `OnboardingSpecHelpers` for `have_welcome_new_author_banner`.

```ruby
# spec/support/post_spec_helpers.rb
module PostSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :have_publish_button_for_post do |post|
    # ...
  end
end

RSpec.configure do |config|
  config.include PostSpecHelpers, type: :request
  config.include PostSpecHelpers, type: :feature
end
```

### Matchers for helpers

Give each helper that builds a simple view element a matcher, named after the helper with a `have_` prefix, e.g. `have_unknown_value_tag` for `unknown_value_tag`. See [Views and Frontend: Helpers](../../views/#helpers). Specs then check for the element the same way on every page, and say what they expect to see, not the markup. When the helper's markup changes, change the matcher next to it.

Put the matchers in a module named after the helper module, with a `SpecHelpers` suffix, e.g. `UnknownValuesSpecHelpers` in `spec/support/unknown_values_spec_helpers.rb` for `UnknownValuesHelper`. Include it in helper specs too. The helper's own spec then checks the helper's output with the matcher, so the two can't drift apart.

```ruby
# spec/support/unknown_values_spec_helpers.rb
module UnknownValuesSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :have_unknown_value_tag do
    match do |actual|
      expect(actual).to have_css("span[aria-label='Unknown']", text: "—")
    end
  end
end

RSpec.configure do |config|
  config.include UnknownValuesSpecHelpers, type: :helper
  config.include UnknownValuesSpecHelpers, type: :request
  config.include UnknownValuesSpecHelpers, type: :feature
end
```

```ruby
RSpec.describe UnknownValuesHelper do
  describe "#unknown_value_tag" do
    it "shows an unknown value" do
      expect(helper.unknown_value_tag).to have_unknown_value_tag
    end
  end
end
```

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id" do
    it "shows an unknown value for a draft's publish date" do
      draft = create(:post, published_at: nil)

      get post_path(draft)

      expect(response.body).to have_unknown_value_tag
    end
  end
end
```
