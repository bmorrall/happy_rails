---
title: RSpec and FactoryBot
parent: Gems
grand_parent: Testing
nav_order: 8
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

### Time helpers

Include `ActiveSupport::Testing::TimeHelpers` for every spec, in `spec/support/time_helpers.rb`. Every spec can then fix the time with `travel_to`. rspec-rails sets the clock back after each example.

```ruby
# spec/support/time_helpers.rb
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end
```

When a spec checks a time, or the code works one out, e.g. which drafts no one has changed for a year, call `travel_to` on the example's first line, and leave a blank line after it. Then match each time exactly with `eq`. A loose match, e.g. `be_within(1.second)` or `an_instance_of(ActiveSupport::TimeWithZone)`, still passes when the code saves the wrong time.

```ruby
it "archives the posts" do
  travel_to Time.zone.now

  post = create(:post)

  described_class.call(Post.where(id: post))

  expect(post.reload.archived_at).to eq(Time.zone.now)
end
```

Use `travel_to Time.zone.now` when the spec only needs the clock to stop, as above. When the code depends on the date, pass a fixed time that tests it, e.g. `travel_to Time.zone.local(2026, 10, 31, 23, 59)` for code that works out the end of a month.

Avoid passing a block to `travel_to`. Call it on its own line, so the whole example runs at the same time, and the setup shows what time it is.

`travel_to` stops the clock on a whole second. Databases store times at different precisions, but every one stores a whole second exactly, so the time you read back matches. You MUST NOT pass `with_usec: true`. The database might then round the microseconds, and the match fails on one database but not another.

#### The current time

You MAY declare `let(:current_time) { Time.zone.now.change(usec: 0) }` as the first line of the top-level `describe` block. Examples then use one name for the time, and build times from it, e.g. `current_time - 13.months`. Drop the microseconds: `travel_to` stops the clock on a whole second, so `Time.zone.now` in the code has none, and an `eq` against a time that keeps them fails.

When the spec's fixtures only work at one time, set `current_time` to that time instead, e.g. `let(:current_time) { Time.zone.local(2026, 3, 14, 9, 30) }` for a recorded reply from the newsletter service with a token that expires. A fixed time doesn't need the `change`.

Stop the clock at `current_time` in a `before` on the next line, `before { travel_to current_time }`. Every example in the spec then runs with the clock stopped. Otherwise the code reads the time a moment after the `let` does, and the two can land on different seconds. The `before` runs ahead of every `let!` and `before` below it, so the records they create get the stopped time too. A `travel_to` on the example's first line runs after them.

With the clock stopped, time only moves when the spec moves it, e.g. `travel 31.minutes` for a token that expires after 30 minutes. The spec then shows how much time passes. Records an example creates get the same `created_at`, so set it when the spec checks the order, as in [Values you check](#values-you-check).

When some examples depend on the date, put them in a context named for the time, e.g. `context "on a leap day"`. Override `current_time` with a fixed time that tests it. The `before` at the top reads the overridden time, so the context doesn't need its own `travel_to`. This is the one `let` you MAY override in a context, as an exception to [Contexts](#contexts). The context's name tells the reader which time its examples run at.

```ruby
RSpec.describe PurgeAbandonedDraftsJob do
  let(:current_time) { Time.zone.now.change(usec: 0) }
  before { travel_to current_time }

  describe ".perform_now" do
    it "deletes drafts no one has changed for a year" do
      post = create(:post, updated_at: current_time - 13.months)

      described_class.perform_now

      expect(Post.exists?(post.id)).to be(false)
    end

    context "on a leap day" do
      let(:current_time) { Time.zone.local(2028, 2, 29, 12) }

      it "deletes a draft changed before noon on February 28 last year" do
        post = create(:post, updated_at: Time.zone.local(2027, 2, 28, 11))

        described_class.perform_now

        expect(Post.exists?(post.id)).to be(false)
      end

      it "keeps a draft changed after noon on February 28 last year" do
        post = create(:post, updated_at: Time.zone.local(2027, 2, 28, 13))

        described_class.perform_now

        expect(Post.exists?(post.id)).to be(true)
      end
    end
  end
end
```

### Record identifiers

Include `ActionView::RecordIdentifier` for every spec, in `spec/support/record_identifier.rb`. Every spec can then call `dom_id` on its own, e.g. `dom_id(comment)`, to find the element a view gives that id.

```ruby
# spec/support/record_identifier.rb
RSpec.configure do |config|
  config.include ActionView::RecordIdentifier
end
```

### Capybara matchers

Include `Capybara::RSpecMatchers` in request specs and feature specs, in `spec/support/capybara.rb`. When a gem's specs check HTML too, add its spec type here, e.g. `type: :component` for [ViewComponent](../view_component/#setup). Request specs can then check the HTML in a response with the same matchers as feature specs, e.g. `have_link` or `have_field`. A matcher checks an element and its text, which `include` can't do.

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

You MUST NOT check for the text alone.

```ruby
expect(response.body).to include("Hello World")
```

You MUST NOT compare the whole body, e.g. with `eq` or a snapshot. It breaks on every change to the markup, and doesn't say which part the example is about. Check each value with its own matcher.

When you check a select's options with `with_options:`, check one option on each line. A failure then names the option that's missing. With every option in one list, the failure only says the list didn't match.

```ruby
expect(response.body).to have_select("Status", with_options: ["Draft"])
expect(response.body).to have_select("Status", with_options: ["Published"])
```

You MUST NOT check them all in one line.

```ruby
expect(response.body).to have_select("Status", with_options: ["Draft", "Published"])
```

### Faker

Set up Faker for every spec, in `spec/support/faker.rb`. Factories use it for [random values](#random-values).

Give Faker the same seed as RSpec. Faker has its own random generator, so without this, `rspec --seed 1234` runs the specs in the same order but with different values. With the seed set, a spec that failed on a random value fails again when you run it with the same seed.

Clear Faker's `unique` values after each example. `unique` remembers every value it has handed out. Over a long run, a generator with few values, e.g. first names, runs out and raises `Faker::UniqueGenerator::RetryLimitExceeded`. The database is cleaned after each example too, so a value from an earlier example can't clash.

```ruby
# spec/support/faker.rb
RSpec.configure do |config|
  config.before(:suite) { Faker::Config.random = Random.new(config.seed) }
  config.after { Faker::UniqueGenerator.clear }
end
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

`||=` keeps a type that a spec sets itself. Do the same for any other folder rspec-rails doesn't know, e.g. `spec/components/` for [ViewComponent](../view_component/#setup). Include setup for form specs with `type: :form`, e.g. `config.include Shoulda::Matchers::ActiveModel, type: :form`. See [Shoulda Matchers: Validations](../shoulda_matchers/#validations).

### Action specs

Give action specs an `:action` type in `spec/support/actions.rb`, in the same way. Include setup for action specs with `type: :action`, e.g. the Turbo matchers. See [Turbo: Action specs](../turbo/#action-specs).

```ruby
# spec/support/actions.rb
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/actions/}) do |metadata|
    metadata[:type] ||= :action
  end
end
```

> **TODO:** Describe how you handle the rest of this.

## Layout and naming

> **TODO:** Describe how you handle this.

### Contexts

Build the records each example needs inside the example, and name the example after the path it takes. Each example then shows all of its setup, and you don't have to trace a `let` up through the blocks above it. A method with an `if` needs two examples, not two contexts.

```ruby
RSpec.describe PostDecorator do
  describe "#published_on" do
    it "returns the date it was published" do
      post = instance_double(Post, published_at: Time.zone.local(2026, 10, 3, 9, 30))
      decorator = described_class.new(post)

      expect(decorator.published_on).to have_date_tag(Date.new(2026, 10, 3))
    end

    it "returns the unknown value tag for a draft" do
      post = instance_double(Post, published_at: nil)
      decorator = described_class.new(post)

      expect(decorator.published_on).to have_unknown_value_tag
    end
  end
end
```

Only write a `context` when several examples share setup that the other examples in the `describe` don't. A `context` MAY hold every example in its `describe` when its name gives the state they run in, e.g. `context "with a published post"`. You MUST NOT write a `context` for one example, and you MUST NOT set up a default with `let` for a `context` to override, other than `current_time`, see [The current time](#the-current-time).

The contexts that request specs require are the exception: a context for each persona, for each way the request can be authenticated, and for a Turbo Stream. Write them even when they hold one example. Define the user and the records each persona needs in its own context, as described in [Personas](#personas).

### let and let!

Only declare a `let` for the setup a `context` is about. Every example in the context runs with that setup, even one that doesn't read it. That setup is:

- the persona's signed-in `user`, and the records that give it its role, e.g. in `context "as a user", "with a post as the author"`
- the state the context is named for, e.g. `let(:draft) { create(:post, published_at: nil) }` in `context "with a draft post"`
- setup the examples share, e.g. the comment that each example in `context "with a comment awaiting approval"` approves or rejects

You MUST NOT declare a `let` for a record only some examples need. Build it inside the example that needs it. The other examples then don't carry setup they never use.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts", :aggregate_failures do
    context "as a user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "lists my drafts" do
        create(:post, author: user, title: "My draft", published_at: nil)

        get posts_path

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_link("My draft")
      end

      it "does not list another author's draft" do
        their_draft = create(:post, published_at: nil)

        get posts_path

        expect(response).to have_http_status(:ok)

        expect(response.body).not_to have_link(their_draft.title)
      end
    end
  end
end
```

You MUST NOT declare a `let` for the one example that uses it:

```ruby
context "as a user" do
  let(:user) { create(:user) }

  # Don't do this
  let(:other_post) { create(:post, title: "Their draft", published_at: nil) }

  # ...
end
```

Declare a `let` in the `context` it's for. You MUST NOT declare a `let` in a `describe` block. A `describe` names the method or route under test, not the setup its examples run with. There are three exceptions: `let(:current_time)` at the top of the spec, see [The current time](#the-current-time), a stubbed service double in an action spec, see [Actions](../../actions/), and the stand-in record in a validator spec, see [Validators](../../validators/). This rule doesn't cover `subject`, e.g. `subject(:post)` in a model spec, see [Models](../../models/#spec-layout).

You SHOULD use `let!` for a record that an example checks with `expect { }.to change` or `not_to change`. A lazy `let` that's first read inside the block creates its record there, so the change could come from the factory, not from the code under test. E.g. with a lazy `let(:draft)`, `delete post_path(draft)` creates the post and deletes it inside the block, so `Post.count` doesn't change.

```ruby
context "as a user", "with a draft post as the author" do
  let(:user) { create(:user) }

  let!(:draft) { create(:post, author: user) }

  before { sign_in user }

  it "deletes the post" do
    expect {
      delete post_path(draft)
    }.to change(Post, :count).by(-1)

    # ...
  end
end
```

Don't leave the record lazy:

```ruby
context "as a user", "with a draft post as the author" do
  let(:user) { create(:user) }

  # Don't do this
  let(:draft) { create(:post, author: user) }

  # ...
end
```

Also use `let!` when a context's examples need a record to exist without naming it, e.g. a post that a list shows. Otherwise use `let`. When only one example needs the record, call `create` in that example, before the `expect` block.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts", :aggregate_failures do
    context "with a published post" do
      let!(:published_post) { create(:post, title: "Hello World", published_at: Time.zone.now) }

      it "lists the post" do
        get posts_path

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_link("Hello World")
      end

      # ...
    end
  end
end
```

## Factories

### Doubles, build_stubbed or create

Pick the lightest stand-in for a record that the code under test allows. The lighter it is, the quicker the spec runs.

In a unit spec, e.g. a decorator or action spec, build the record with an `instance_double`, and stub only the values the code reads. The spec then runs without the database, and shows exactly what the code reads from the record. Use `instance_double`, not a plain `double`. It fails when you stub a method the class doesn't have, so the stubs can't drift away from the real code.

```ruby
post = instance_double(Post, published_at: nil)
```

When an `instance_double` can't stand in for the record, use `build_stubbed`, e.g. when the code passes the record to a route helper or a form, or reads so many values that stubbing them all hides what the spec is about. `build_stubbed` gives the record an `id` and makes it look saved, without touching the database, so it is much quicker than `create`.

```ruby
post = build_stubbed(:post, title: "Hello")
```

Use `create` only when the code needs the record in the database, e.g. when it runs a query, or a request or feature spec loads the record by its ID. Specs that run the whole stack, e.g. request, feature and job specs, use real records. See [Jobs: Job specs](../../jobs/).

```ruby
post = create(:post, title: "Hello")
get post_path(post)
```

> **TODO:** Describe how you handle the rest of this.

### Message chains

You SHOULD NOT stub a chain of calls with `receive_message_chain`. A chain stub hides which object does what, and it keeps passing when a step in the chain changes. Move the chain into a method on the class it starts from, so the spec stubs one method. For example, use a scope or a scoped association on the model, such as `post.approved_comments` for `post.comments.approved`, or a `perform_later_` method on a job, such as `PublishScheduledPostJob.perform_later_for(post)`. See [Models: Scopes and queries](../../../guide/models/#scopes-and-queries) and [Jobs: Jobs that run at a set time](../../../guide/jobs/#jobs-that-run-at-a-set-time).

```ruby
allow(post).to receive(:approved_comments).and_return(comments)
```

```ruby
# Don't do this
allow(post).to receive_message_chain(:comments, :approved).and_return(comments)
```

### Random values

You SHOULD give each attribute in a factory a random value from [Faker](https://github.com/faker-ruby/faker), e.g. `name { Faker::Name.name }`, not a fixed one, e.g. `name { "Jane Tester" }`. Random values test the code with data you didn't think of, e.g. a name with an apostrophe or a long title. They also catch a spec that checks a default, as in [Values you check](#values-you-check). The value changes from run to run, so the spec fails.

When a column has to be unique, e.g. `email`, put a number in the value. Faker can give two records the same value, but the number never repeats, so they never clash. The number also makes records easy to tell apart when you read them, e.g. `user1@` and `user2@`.

You SHOULD take the number from a `counter` sequence in a `transient` block:

- A `sequence` counts up by one for each record the factory builds: 1, 2, 3.
- A `transient` attribute is one the factory can read, but doesn't set on the record. `User` doesn't need a `counter` column.

Build each unique value from `counter`, e.g. `user1@` in the first user's email. Use one counter for the whole factory, not a sequence for each attribute. When a spec sets an attribute itself, e.g. `create(:user, email: "jane@example.com")`, that attribute's sequence doesn't count up, so separate sequences drift apart. With one counter, every value on a record has the same number, so you can tell which record a value belongs to, e.g. in a failure message.

You MAY use Faker's `unique` instead, e.g. `Faker::Internet.unique.email`. It also never repeats a value, but its values don't show which record is which.

```ruby
FactoryBot.define do
  factory :user do
    transient do
      sequence(:counter)
    end

    email { Faker::Internet.email(name: "user#{counter}") }
    name { Faker::Name.name }
  end
end
```

When a unique value has a set format, e.g. a magazine's ISSN, build it from the counter with `format`. Pad the number to the format's length, so every value has the right shape. Magazine 3 is then "Fantasy Monthly 3", with the ISSN `0000-0003`.

```ruby
FactoryBot.define do
  factory :magazine do
    transient do
      sequence(:counter)
    end

    name { "#{Faker::Book.genre} Monthly #{counter}" }
    issn { format("0000-%04d", counter) }
  end
end
```

## Traits

Give a factory a trait for each state a page shows differently. Name it after the state the app uses, e.g. `:published` or `:archived`. When a job or an action adds values to the record, add a trait for the record after that work, named after what happened, e.g. `:sent_to_subscribers`.

Set the values the state needs, so the record is valid and looks like a real one in that state, e.g. the status, and a `rejection_reason` for a rejected post. A request or feature spec can then check those values without setting them, through a format helper. See [Values the example didn't set](#values-the-example-didnt-set).

```ruby
FactoryBot.define do
  factory :post do
    # ...

    trait :published do
      status { :published }
    end

    trait :rejected do
      status { :rejected }
      rejection_reason { Faker::Lorem.sentence }
    end
  end
end
```

### Persona traits

Give the user factory one trait for each role on the whole app, named after the role, e.g. `:app_admin`, `:publishing_manager` and `:copy_editor`. Use a trait for a flag on the user too, e.g. `:employee`. Define the traits in rank order. A plain `create(:user)` is the User persona, with no role. See [Principles: Personas](../../../guide/principles/#personas).

```ruby
FactoryBot.define do
  factory :user do
    transient do
      sequence(:counter)
    end

    email { Faker::Internet.email(name: "user#{counter}") }
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

You MUST NOT add a trait for a role on a record, e.g. the Author of a post. Build a plain user, then give it the role on the record, e.g. `create(:post, author: user)`. Then the spec shows how the user gets access to that record. For a persona with more than one role, build the user with the trait for the whole-app role, then give it the role on the record.

## Values you check

Set every value an example checks in the spec, where the reader can see it, e.g. in the example or in its context's `let`. You MUST NOT check against a default from a factory or a stub helper. That includes the records a factory builds for you, e.g. the author of `build_stubbed(:post)`, and the reply a stub helper sends when you don't pass one, e.g. the ID from `stub_newsletter_create`. Leave the values the example doesn't check to the defaults.

You SHOULD give factories and stub helpers a default for every value they need, e.g. `id: "newsletter-1"` in `stub_newsletter_create`. A spec then passes only the values it's about, and `create(:post)` or `stub_newsletter_create` works with no arguments. Require an argument only when the helper can't pick a default, e.g. the integration in `stub_newsletter_client_for(integration)`, which the stub is built from.

Pass a value the spec checks even when it's the same as the default, e.g. `stub_newsletter_create(id: "newsletter-1")`.

A default is set in another file, so the reader can't see where the value comes from. A change to the default breaks specs that aren't about it. And the code can pass by chance, e.g. when it hardcodes the same value as the default.

The spec below doesn't set the author's name, so it checks whatever name the user factory gives the author:

```ruby
# Don't do this
it "returns the author's name" do
  post = build_stubbed(:post)

  expect(post.decorate.author_name).to eq("Jane Tester")
end
```

```ruby
it "returns the author's name" do
  author = build_stubbed(:user, name: "Jane Tester")
  post = build_stubbed(:post, author:)

  expect(post.decorate.author_name).to eq("Jane Tester")
end
```

Check against the value you set, e.g. `"Jane Tester"`. You MUST NOT check against a value you read back from a record, e.g. `post.author.name`. The read gives the same answer as the code under test, so the check passes whatever the value is. Read from the record only when the spec can't set the value, e.g. a record's `id`, or through a format helper in a request or feature spec, as in [Values the example didn't set](#values-the-example-didnt-set).

```ruby
# Don't do this
expect(post.decorate.author_name).to eq(post.author.name)
```

### Values the example didn't set

In request and feature specs, a page often shows values the example didn't set, e.g. the name of a parent several levels up, or a value a [trait](#traits) sets. You MAY check these by reading them from the record through a format helper, e.g. `format_text(comment.post.magazine.name)`. Then the example doesn't have to build every parent just to see its name on the page. The values the example is about still need to be set in the spec, as above. Unit specs, e.g. decorator and helper specs, set every value they check.

A format helper turns a record's value into the text the page shows, and raises when there's no value. Use `format_text` for a string, and `format_date` or `format_datetime` for a time. You MUST NOT read the value without one, e.g. `have_link(comment.post.magazine.name)`. Capybara ignores a `nil` locator or `text:`, so the check would pass whatever the page shows.

Write each format in the helper, the same way the app formats it, e.g. `I18n.l(value, format: :long)`. You MUST NOT call the app's own helpers, e.g. `date_tag`. The spec would then pass with a wrong format.

```ruby
# spec/support/format_spec_helpers.rb
module FormatSpecHelpers
  def format_text(value)
    value.presence || raise(ArgumentError, "expected a value to check, got #{value.inspect}")
  end

  def format_date(value)
    I18n.l(value.to_date, format: :long)
  end

  def format_datetime(value)
    I18n.l(value, format: :long)
  end
end

RSpec.configure do |config|
  config.include FormatSpecHelpers, type: :request
  config.include FormatSpecHelpers, type: :feature
end
```

```ruby
RSpec.describe "Comments" do
  describe "GET /comments/:id", :aggregate_failures do
    context "as a user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "links to the post's magazine" do
        comment = create(:comment)

        get comment_path(comment)

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_link(format_text(comment.post.magazine.name))
      end
    end
  end
end
```

### Shared identifiers

When a spec uses an identifier in more than one place, e.g. a newsletter ID it passes to a stub helper and then checks, you SHOULD declare it once and use the name everywhere. Declare it in a local variable in the example, e.g. `newsletter_id = "newsletter-1"`. When the examples in a context all use it, declare it in a `let` in that context instead, e.g. `let(:newsletter_id) { "newsletter-1" }`. You MUST NOT add a context only to hold the `let`. Examples without one each declare their own. You SHOULD NOT write the same literal twice. A typo in one copy makes a `to` check fail for the wrong reason and a `not_to` check pass for the wrong reason. The name also tells the reader what the value is.

You SHOULD NOT read an identifier out of a fixture in a spec, e.g. `JSON.parse(file_fixture("newsletter_create.json").read)["id"]`. The reader has to open the fixture to see the value, and the spec breaks when someone edits the fixture. Declare the identifier in the spec, and pass it to the stub helper, which puts it into the reply.

```ruby
# Don't do this
it "returns the newsletter's ID" do
  stub_newsletter_create

  response = described_class.new(api_key: "test-key").create_public_newsletter(title: "Hello World", body: "My first post.")

  expect(response.id).to eq(JSON.parse(file_fixture("newsletter_create.json").read)["id"])
end
```

```ruby
it "returns the newsletter's ID" do
  newsletter_id = "newsletter-1"
  stub_newsletter_create(id: newsletter_id)

  response = described_class.new(api_key: "test-key").create_public_newsletter(title: "Hello World", body: "My first post.")

  expect(response.id).to eq(newsletter_id)
end
```

### Checks with not_to

A `not_to` check is the other way round. You SHOULD take the value it looks for from the records the spec set up, e.g. `post.title` or `post.slug`, not a value you wrote in. A `not_to` check passes whatever value it looks for, as long as that value isn't there. When the value you wrote in doesn't match the setup, e.g. a title the factory never gave the post, the check passes even if the code is wrong. A value read from the record always matches the setup, even after the setup changes.

```ruby
# Don't do this
it "does not list another author's draft" do
  create(:post, published_at: nil)

  get posts_path

  expect(response.body).not_to have_link("Their draft")
end
```

```ruby
it "does not list another author's draft" do
  their_draft = create(:post, published_at: nil)

  get posts_path

  expect(response.body).not_to have_link(their_draft.title)
end
```

When you check that the code leaves a value alone, check it against the record's value from before the code ran. Use `not_to change`, e.g. `not_to change { draft.reload.title }`. You MUST NOT check it with `not_to` and a value you wrote in, e.g. `not_to eq("New title")`. That check passes when the code changes the value to anything else, e.g. a blank title or the wrong post's title.

```ruby
# Don't do this
it "does not update the post" do
  patch post_path(draft), params: { post: { title: "New title" } }
  expect(draft.reload.title).not_to eq("New title")
end
```

```ruby
it "does not update the post" do
  expect {
    patch post_path(draft), params: { post: { title: "New title" } }
  }.not_to change { draft.reload.title }
end
```

RSpec doesn't support `to` after `not_to change`, e.g. `not_to change { draft.reload.title }.to("New title")`. It raises an error.

## Generated values

When the code generates a value, e.g. a token or a key, match it as closely as the spec can. A loose match still passes when the code builds the value wrongly.

Match a string with a known format with `match`, or `a_string_matching` inside another matcher, and a regexp for the whole string. Write in what the spec knows, e.g. the length and characters of a token made with `SecureRandom.urlsafe_base64`, or a record's ID when the code builds it into the value. Use `a_kind_of(String)` only as a last resort, when the string has no format the spec can describe.

When the code saves something made from the value, check that too, e.g. the digest of a preview token saved on the post. The spec can't know the token, but it can check that the code kept the right digest of it.

```ruby
RSpec.describe SharePostForm do
  describe "#submit" do
    it "makes a preview token for the post" do
      post = create(:post)

      result = described_class.new(post, post.author).submit

      expect(result.token).to match(/\A[\w-]{22}\z/)
      expect(post.reload.preview_token_digest).to eq(Digest::SHA256.hexdigest(result.token))
    end
  end
end
```

Inside another matcher, use `a_string_matching` in the same way, e.g. for a request ID that a service makes for each call and sends in a header.

```ruby
expect(WebMock).to have_requested_newsletter_create(
  headers: { "X-Request-Id" => a_string_matching(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/) }
)
```

## Request specs

Write a request spec for every controller. See [Controllers and Routes: Request specs](../../controllers/#request-specs) for where to put it and how to lay out its `describe` blocks.

### Personas

Write a context for the personas each action needs, as described in [Principles: Personas](../../../guide/principles/#personas).

Only write persona contexts for actions where access depends on who the user is. Some actions don't check a user at all, e.g. an API that authenticates with a shared token, or a callback from another service. Leave out the persona contexts for these. Write a context for each way the request can be authenticated instead, e.g. `"with an access token"`, `"with an invalid access token"` and `"without an access token"`. See [Controllers and Routes: Authentication](../../../guide/controllers/#authentication).

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

Write one `context` for each persona whose role plays a part in the action, and for the User and the Guest. Put them in rank order, with the Guest last. Leave out a persona whose role plays no part in the action, e.g. the Copy Editor and the Author in a spec for publishing a post. Neither role has anything to do with publishing, so they get the same answer as the User. The policy spec tests each property the rule reads, so it covers them too. See [Pundit: Policy specs](../pundit/).

Name the context after the persona's role on the whole app, e.g. `"as a publishing manager"`, so the reader can tell what it's for. A role through membership of a parent record goes here too, see [Roles through a membership](#roles-through-a-membership). Use `"as a user"` for a persona with neither, and `"when not signed in"` for the Guest. Keep `"as a"` for personas, and name other contexts another way, e.g. `"with a Turbo Stream"`.

When the persona's role is on the record under test, describe the record in a second argument to `context`, with the role after it, e.g. `context "as a user", "with a post as the author"`. The first argument then always names the persona's own role, and the second names the record and any role the persona holds on it. For a persona with both, put each in its own argument, e.g. `context "as a copy editor", "with a post as the author"`.

When a context uses a record the persona has no role on, describe that record in the second argument, e.g. `context "as a user", "with a post written by another user"`. When the context needs the record in a particular state, put the state in the record's description, e.g. `context "as a user", "with a draft post as the author"`. RSpec joins the two into one description.

Set up the persona inside its context, as a signed-in `user`. Build the user with a [persona trait](#persona-traits) for a role on the whole app, or give it the role on the record. Define the `user` and the records the context needs inside the context, not in the `describe` block above it. You MUST NOT define a `let` for each persona, e.g. `let(:author)`. Then every context reads on its own, in the same way, and shows how the user gets their access.

You MAY give the user a person's name, e.g. Jane Tester, if it makes the spec easier to read. Still give the role in the context name.

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

An Author can update a post they wrote, but not someone else's. The second context is a user with a post of their own, so they're an Author, but not of the post the request acts on. Its second argument says so. The User and Guest contexts are left out to keep the example short.

```ruby
RSpec.describe "Posts" do
  describe "PATCH /posts/:id", :aggregate_failures do
    context "as a user", "with a post as the author" do
      let(:user) { create(:user) }

      let(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "updates the post" do
        patch post_path(draft), params: { post: { title: "New title" } }
        expect(draft.reload.title).to eq("New title")
      end
    end

    context "as a user", "with a post written by another user" do
      let(:user) { create(:user) }

      let!(:draft) { create(:post) }

      before do
        create(:post, author: user)
        sign_in user
      end

      it "does not update the post" do
        expect {
          patch post_path(draft), params: { post: { title: "New title" } }
        }.not_to change { draft.reload.title }
      end
    end
  end
end
```

#### Roles through a membership

Some roles come from membership of a parent record, and cover the records inside it. E.g. a Magazine Editor can edit every post in the magazines they edit. Name the context after the membership role, in the first argument, the same as a role on the whole app, e.g. `context "as a magazine editor"`. The role belongs to the persona, not to one post, so it doesn't go in the second argument.

Give the user the membership in the persona's `let`s, e.g. `let!(:magazine) { create_magazine_with_magazine_editor(user) }`. Use `let!`, because the request reads the membership, and an example might never name it. The magazine is part of the persona's setup, so it sits with the `user`, in the persona's group of `let`s.

You SHOULD write a helper for each membership role, named `create_<parent>_with_<role>`, and use it instead of building the membership inline. It takes the user, gives it the role, and returns the parent record. Put it in the parent's spec helpers module, e.g. `MagazineSpecHelpers`, see [Where to put matchers](#where-to-put-matchers). Every spec then gives a user the role the same way, and a change to how memberships work only changes the helper.

```ruby
# spec/support/magazine_spec_helpers.rb
module MagazineSpecHelpers
  def create_magazine_with_magazine_editor(user)
    create(:magazine, editors: [user])
  end
end

RSpec.configure do |config|
  config.include MagazineSpecHelpers, type: :request
end
```

When the persona's examples act on different posts, e.g. a post in its magazine and a post in another magazine, write one context with no second argument. Build each post in the example that needs it, and name the example after where the post sits, e.g. `it "updates a post in the magazine"` and `it "does not update a post in another magazine"`. The context is about the persona, and each example shows which post it acts on. Use this shape whenever the spec covers a post outside the membership.

```ruby
RSpec.describe "Posts" do
  describe "PATCH /posts/:id", :aggregate_failures do
    context "as a magazine editor" do
      let(:user) { create(:user) }
      let!(:magazine) { create_magazine_with_magazine_editor(user) }

      before { sign_in user }

      it "updates a post in the magazine" do
        draft = create(:post, magazine:)

        patch post_path(draft), params: { post: { title: "New title" } }
        expect(draft.reload.title).to eq("New title")
      end

      it "does not update a post in another magazine" do
        draft = create(:post)

        expect {
          patch post_path(draft), params: { post: { title: "New title" } }
        }.not_to change { draft.reload.title }
      end
    end
  end
end
```

When every example acts on the same post, describe it in the second argument instead, with its state and where it sits. This follows the same state rule as other personas.

```ruby
context "as a magazine editor", "with a draft post in the magazine" do
  let(:user) { create(:user) }
  let!(:magazine) { create_magazine_with_magazine_editor(user) }

  let(:draft) { create(:post, magazine:, published_at: nil) }

  before { sign_in user }

  # ...
end
```

Cover posts outside the membership in a context with no second argument next to it. Like any persona context, it MAY hold one example.

```ruby
context "as a magazine editor" do
  let(:user) { create(:user) }
  let!(:magazine) { create_magazine_with_magazine_editor(user) }

  before { sign_in user }

  it "does not update a post in another magazine" do
    draft = create(:post, published_at: nil)
    # ...
  end
end
```

A role on the post still goes in the second argument, e.g. `context "as a magazine editor", "with a post as the author"`. Build that post in the persona's magazine.

```ruby
context "as a magazine editor", "with a post as the author" do
  let(:user) { create(:user) }
  let!(:magazine) { create_magazine_with_magazine_editor(user) }

  let(:draft) { create(:post, magazine:, author: user) }

  # ...
end
```

For a persona with a role on the whole app and a membership role, name both in the first argument, highest first, e.g. `context "as a publishing manager as a magazine editor"`. Both are roles the persona holds, so they stay together.

Rank a membership persona with the others, by the app's persona list, e.g. the Magazine Editor after the Copy Editor. See [The example app: Personas](../../../example-app/#personas).

### Responses

Check the response of every request. When the action responds with a page or data, check the status with `have_http_status`, e.g. `expect(response).to have_http_status(:ok)`. Leave a blank line above and below it, so the status stands apart from the request and from the checks on the body.

Pass `have_http_status` a named status, e.g. `:not_found` or `:unprocessable_content`. You MUST NOT pass a number, e.g. `have_http_status(404)`. The name says what the status means, so the reader doesn't have to look it up.

You MUST NOT check a status with `be_successful`, `be_ok`, `be_redirect`, `be_not_found` or a status type, e.g. `have_http_status(:success)`. Some accept a range of statuses, e.g. `be_successful` passes for a `204` when the action has to return `200`. None of them say which status came back when they fail. `have_http_status` with a named status checks one status, and its failure message shows the one it got.

When the action redirects, check where it redirects to with `redirect_to`, e.g. `expect(response).to redirect_to(post_path(draft))`. On the next line, check the flash with the matcher for its key, e.g. `expect(flash).to have_flash_notice("Post was updated.")`. Each one checks the whole flash, not one key. If the action sets any other flash, e.g. an `alert` as well as the `notice`, the spec fails and the failure message shows the flash it got. You MUST NOT check a single flash key, e.g. `flash[:notice]`, or compare the flash hash by hand. You MUST NOT check a redirect with `have_http_status(:found)` or `be_redirect`. `redirect_to` checks the status and where it goes.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id", :aggregate_failures do
    context "as a user", "with a post as the author" do
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
    context "as a user", "with a post as the author" do
      let(:user) { create(:user) }

      let!(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "updates the post" do
        expect {
          patch post_path(draft), params: { post: { title: "New title" } }
        }.to change { draft.reload.title }.to("New title")

        expect(response).to redirect_to(post_path(draft))
        expect(flash).to have_flash_notice("Post was updated.")
      end

      it "shows the form again with a blank title" do
        expect {
          patch post_path(draft), params: { post: { title: "" } }
        }.not_to change { draft.reload.title }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
```

When the action renders a page with `flash.now`, check the message in the response body, with a matcher for the element that shows it, e.g. `have_css` with `text:`. `flash.now` is only for the page the action renders, so what matters is that the page shows it. You MUST NOT check it with a flash matcher, e.g. `have_flash_alert`. It checks the flash, not the page, so it passes when the layout never shows the message.

```ruby
it "warns that the post is archived" do
  get edit_post_path(archived)

  expect(response).to have_http_status(:ok)

  expect(response.body).to have_css("[role='alert']", text: "This post is archived.")
end
```

Don't check a status with a generic matcher or a number:

```ruby
# Don't do this
expect(response).to be_successful
expect(response).to have_http_status(200)
```

The flash matchers live in `spec/support/flash_spec_helpers.rb`, included for request specs. There's one for each flash key the app uses, named `have_flash_<key>`. List the keys in `FLASH_KEYS`, e.g. add `success` and `error` for an app with `add_flash_types :success, :error`.

```ruby
# spec/support/flash_spec_helpers.rb
module FlashSpecHelpers
  extend RSpec::Matchers::DSL

  FLASH_KEYS = %w[notice alert].freeze

  FLASH_KEYS.each do |key|
    matcher :"have_flash_#{key}" do |message|
      match { |flash| values_match?({ key => message }, flash.to_hash) }
      failure_message { |flash| "expected the flash to be #{{ key => message }}, but it was #{flash.to_hash}" }
    end
  end
end

RSpec.configure do |config|
  config.include FlashSpecHelpers, type: :request
end
```

### Several checks per request

Request specs are slow, because each one goes through routing, the controller and the views. Make one request in each example, and check as much as you can about it there: the records it changed, the status or redirect, the flash and the body. You MUST NOT repeat the same request in several examples, each with one check.

Tag each action's `describe` block with `:aggregate_failures`, e.g. `describe "POST /posts", :aggregate_failures do`. RSpec then runs all the checks in an example and reports every one that fails, not only the first.

Wrap the request in `expect { }.to change` when it changes a record, e.g. `change(Post, :count).by(1)` or `change { draft.reload.title }`. The spec then shows what the request changed, in the same step as the request. When the request changes nothing, use `not_to change`.

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
        expect(flash).to have_flash_notice("Post was created.")
      end

      it "shows the form again with a blank title" do
        expect {
          post posts_path, params: { post: { title: "" } }
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
```

## Feature specs

Feature specs describe the user stories of the app. Each one shows a persona using a feature from start to finish.

Write at least one feature spec for every controller that serves pages, so that its scenarios cover the happy path of every HTML route. See [Controllers and Routes: Feature specs](../../controllers/#feature-specs) for which routes to cover.

Use `RSpec.feature` and name it after the feature under test, e.g. `RSpec.feature "Post Publishing"`. Write each example as a `scenario`.

Start each scenario's name with the persona carrying out the task, then say what they want to achieve, e.g. `scenario "Publishing Manager publishes a post"`. Order the scenarios by persona rank, as in [Principles: Personas](../../../guide/principles/#personas).

Write scenarios for what a persona can do, not for what they can't. Request specs and policy specs already cover the actions a persona isn't allowed to take. Only add a scenario for something a persona can't do when it guards against a regression, e.g. a bug that let them do it before, or when the action is critical, e.g. keeping draft posts hidden from Guests.

Carry out several actions in one scenario. Request specs already test each request on its own, and feature specs are slow to run. A scenario that takes a persona through a whole task shows how the parts of the app work together.

Put a `GIVEN`, `WHEN` or `THEN` comment above each step, so the scenario reads as a user story. Write the comments in the first person, as the persona describing the situation and what they do, e.g. `# GIVEN I am signed in as a Publishing Manager`. `GIVEN` sets the scene, `WHEN` is what the persona does, and `THEN` is what they see. When two steps of the same type follow each other, start the second with `AND`. Leave a blank line before each comment, so each step stands apart. A scenario MAY go through `WHEN` and `THEN` more than once. Keep the `GIVEN` steps together at the start. The exception is a mocked response, which MAY have its own `GIVEN` just before the step that needs it, e.g. `# GIVEN the newsletter service accepts the post` before `# WHEN I publish it`.

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

You MUST NOT use `let` or `let!` in feature specs. Build every record in the scenario, under its `# GIVEN` and `# AND` comments, e.g. `create(:post, title: "Hello World")` under `# AND there is a draft post` above. The scenario then tells the whole story, setup included.

### Scoping to a record

In feature specs, when a page shows several records, e.g. the comments on a post, scope each step about one of them to that record's element. Write a helper for each resource that wraps Capybara's `within`, named `within_<resource>` and taking the record, e.g. `within_comment(comment)`. The scenario then says which record it acts on, and the step can't click a button on the wrong comment. When the markup changes, change the helper, not every scenario.

`within` only works in feature specs, so keep the helper apart from the matchers that request specs share. Put it in a module named after the resource with a `FeatureSpecHelpers` suffix, e.g. `CommentFeatureSpecHelpers`, and include it only in feature specs. Keep the module in the resource's support file, next to its spec helpers module, e.g. in `spec/support/comment_spec_helpers.rb` with `CommentSpecHelpers`. The name then says the helper is for feature specs, and you still find everything the specs share about comments in one file. See [Where to put matchers](#where-to-put-matchers).

```ruby
# spec/support/comment_spec_helpers.rb
module CommentSpecHelpers
  # ...
end

module CommentFeatureSpecHelpers
  def within_comment(comment, &)
    within("##{dom_id(comment)}", &)
  end
end

RSpec.configure do |config|
  config.include CommentSpecHelpers, type: :request
  config.include CommentSpecHelpers, type: :feature
  config.include CommentFeatureSpecHelpers, type: :feature
end
```

```ruby
RSpec.feature "Comment Approval" do
  scenario "Author approves a comment" do
    # GIVEN I am signed in as an Author
    user = create(:user)
    sign_in user

    # AND my post has two comments to approve
    published_post = create(:post, status: :published, author: user)
    create(:comment, post: published_post, body: "First!")
    comment = create(:comment, post: published_post, body: "Great post!")

    # WHEN I open the post
    visit post_path(published_post)

    # AND I approve the second comment
    within_comment(comment) do
      click_button "Approve"
    end

    # THEN I see that it was approved
    within_comment(comment) do
      expect(page).not_to have_button("Approve")
    end
  end
end
```

When a step targets a specific element for the record, e.g. a component, add the element to the name, e.g. `within_post_card(post)` for `Posts::CardComponent`. Use the plain `within_<resource>` name for the record's own element.

```ruby
# spec/support/post_spec_helpers.rb
module PostFeatureSpecHelpers
  def within_post_card(post, &)
    within("##{dom_id(post, :card)}", &)
  end
end
```

You MUST NOT scope a step with the record's selector written out, e.g. `within("#comment_#{comment.id}")`.

### API endpoints

Feature specs can cover an API too. Each scenario shows a client using the API for a task from start to finish, the same as a persona using the pages.

Make the requests through an `ActionDispatch::Integration::Session` named `client`, e.g. `client.post` and `client.response`. The client has its own cookies and headers, apart from the browser session, so it sees the API the way a real client does. Write the scenarios and the `GIVEN`, `WHEN` and `THEN` comments the same way as for pages. When the access token belongs to a user, start the scenario's name with the persona. When it doesn't, start with the client, e.g. `scenario "API client writes a post"`.

Authenticate the way the client does. When the API takes an access token, send the token in the request headers. You MUST NOT sign the user in with `sign_in`. The API doesn't use the session, so a spec that signs in could pass even when the token check is broken.

Check that every response matches the pattern you expect: the status, and the shape of the body. Use `match` with RSpec's composable matchers for values the spec can't know in advance, e.g. `an_instance_of(Integer)` for a new ID. A client depends on the shape of each response, so the spec needs to catch a field that goes missing or changes type.

Take the data for each request from the response before it, e.g. the ID of the post you just created. You MUST NOT look the record up in the database, or reuse the record you built with a factory. Then the scenario shows that a client can follow the API from one step to the next, with only what the API gives back.

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

You MUST NOT write the two checks separately.

```ruby
expect(response.body).to have_button("Publish")
expect(response.body).not_to have_css("form[action='#{post_publication_path(published_post)}']")
```

A generic matcher takes no arguments, e.g. `have_welcome_new_author_banner`. A matcher for one record takes the record and ends in `_for_<resource>`, e.g. `have_publish_button_for_post(post)`. The name then says which record the element belongs to. A matcher for a message takes the message, and requires it, e.g. `have_flash_notice("Post was updated.")`.

Define a matcher with `matcher`. Make every matcher work with both `to` and `not_to`, with as little code as it needs. Check the element with a Capybara matcher in its `match` block. When the matcher checks one thing, `match` is all it needs. RSpec runs the same block for `not_to`, and flips the result.

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

Build a complex matcher from simpler ones. Combine them with `and` when the element has more than one part to check, e.g. the banner's heading and its link. Define each part as a private method inside the matcher, with a `have_` prefix and named after what the part is, e.g. `have_welcome_heading` and `have_first_post_link`. The `match` block then reads as a list of parts, and the negated check uses the same parts. You MUST NOT name a part after one of Capybara's matchers, e.g. `have_link` or `have_title`. The part would then call itself instead of Capybara's matcher, and loop until the stack overflows.

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
