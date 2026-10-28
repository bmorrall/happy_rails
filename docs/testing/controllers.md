---
title: Controllers and Routes
parent: Testing
nav_order: 9
---

# Controllers and Routes

How I test controllers and routes.

For the code itself, see [Controllers and Routes](../../guide/controllers/).

## RESTful resources

Order the request specs in `spec/requests` the same way as the controller's actions. Name the top-level `RSpec.describe` block after the controller's resource (`"Posts"` for `PostsController`), then add one `describe` block for each route comment, in the same sequence as the controller. Name each `describe` block with its route, so a controller action and its specs are easy to match up. See [Controllers and Routes: RESTful resources](../../guide/controllers/#restful-resources) for the order of the actions.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts" do
  end

  describe "GET /posts/:id" do
  end

  describe "GET /posts/new" do
  end

  describe "GET /posts/:id/edit" do
  end

  describe "POST /posts" do
  end

  describe "PATCH /posts/:id" do
  end

  describe "DELETE /posts/:id" do
  end
end
```

## Nested resources

Name the request spec for a nested controller after the full controller name (`"Posts::Comments"`) and put it in `spec/requests/posts/comments_spec.rb`.

```ruby
RSpec.describe "Posts::Comments" do
  describe "GET /posts/:post_id/comments" do
  end

  describe "POST /posts/:post_id/comments" do
  end
end
```

## Non-CRUD actions

A controller for a non-CRUD action, e.g. `Posts::PublicationsController`, is named and laid out like any other nested controller.

```ruby
RSpec.describe "Posts::Publications" do
  describe "POST /posts/:post_id/publication" do
  end
end
```

### Custom actions

If a controller has custom actions, add their `describe` blocks to the request spec in the same order as the controller: below the standard actions, in alphabetical order.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id" do
  end

  describe "DELETE /posts/:id" do
  end

  describe "POST /posts/:id/duplicate" do
  end

  describe "GET /posts/:id/preview" do
  end
end
```

## Response formats

Leave the controller's default format out of `describe` blocks, as in its route comments.

When an action also responds to another format, add a matching `describe` block in the request spec, directly after the block for the default format.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts" do
  end

  describe "GET /posts.json" do
  end

  describe "GET /posts/:id" do
  end

  describe "GET /posts/:id.json" do
  end
end
```

### JSON

Request each route the way its clients do. When JSON is another format, the route has an extension, e.g. `GET /posts/:id.json`. Pass the format to the path helper, e.g. `get post_path(published_post, format: :json)`, so the request matches the route in the `describe` block. When JSON is the controller's default format, as in an API, clients don't add the extension. Leave the format out, e.g. `post api_v1_posts_path`.

Send params to a JSON endpoint with `as: :json`. It encodes the params as JSON, and sets the `Content-Type` and `Accept` headers, the way a JSON client sends them. You SHOULD NOT encode the params yourself, e.g. `params: { post: { title: "Hello World" } }.to_json`, or set those headers by hand.

Read the body with `response.parsed_body`. You MUST NOT parse it yourself, e.g. `JSON.parse(response.body)`. `parsed_body` only parses JSON when the response says it's JSON. When the action responds with HTML by mistake, the check fails.

Check the whole body with `match`, as for [API endpoints](../gems/rspec/#api-endpoints). Use RSpec's composable matchers for values the spec can't know in advance, e.g. `an_instance_of(Integer)` for a new ID. Check the body in the happy path, and in each example where the body changes, e.g. the error a failed request returns.

You MUST NOT check the body against JSON the app builds, e.g. `eq(published_post.to_json)` or the output of the serializer. The spec then uses the same code as the action, so it passes when that code drops a field or changes its type. Write out the fields the client gets, with the values you set.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id.json", :aggregate_failures do
    it "responds with the post" do
      published_post = create(:post, title: "Hello World")

      get post_path(published_post, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to match(
        "id" => published_post.id,
        "title" => "Hello World"
      )
    end
  end
end
```

```ruby
RSpec.describe "Api::V1::Posts" do
  describe "POST /api/v1/posts", :aggregate_failures do
    context "with an access token" do
      let(:headers) { { "Authorization" => "Bearer #{Rails.application.credentials.api_token}" } }

      it "responds with the new post" do
        post api_v1_posts_path, params: { post: { title: "Hello World" } }, headers: headers, as: :json

        expect(response).to have_http_status(:created)

        expect(response.headers["Location"]).to eq(api_v1_post_url(Post.last))

        expect(response.parsed_body).to match(
          "id" => an_instance_of(Integer),
          "title" => "Hello World"
        )
      end
    end
  end
end
```

### Turbo Streams

Turbo asks for a stream with the `Accept` header, not a format extension, so a Turbo Stream gets no `describe` block of its own. In the request spec, add a `context "with a Turbo Stream"` inside the route's `describe` block, and send the `Accept` header in that context.

```ruby
RSpec.describe "Posts::Comments" do
  describe "POST /posts/:post_id/comments" do
    context "with a published post" do
      let(:published_post) { create(:post, published_at: Time.zone.now) }

      it "redirects to the post" do
        post post_comments_path(published_post), params: { comment: { body: "Hello" } }

        expect(response).to redirect_to(post_path(published_post))
        expect(flash).to have_flash_notice("Comment was created.")
      end

      context "with a Turbo Stream" do
        it "responds with a Turbo Stream" do
          post post_comments_path(published_post),
            params: { comment: { body: "Hello" } },
            headers: { "Accept" => Mime[:turbo_stream].to_s }

          expect(response).to have_http_status(:ok)

          expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
        end
      end
    end
  end
end
```

## Strong parameters

Send params in the request spec the same way the controller reads them, nested under the resource's singular name.

```ruby
RSpec.describe "Posts" do
  describe "POST /posts" do
    it "creates a post" do
      expect {
        post posts_path, params: { post: { title: "Hello", body: "World" } }
      }.to change(Post, :count).by(1)
    end
  end
end
```

### Unpermitted parameters

When the app raises on unpermitted params, as in [Controllers and Routes: Unpermitted parameters](../../guide/controllers/#unpermitted-parameters), write an example for each attribute the app leaves out on purpose. Send it from a persona who can change the record but not that attribute, e.g. an Author who can change a post's title but can't feature it. Do the same for an action that leaves out an attribute another action accepts, e.g. the slug that `create` accepts and `update` doesn't. Check for `have_http_status(:bad_request)`, and that the record didn't change. For an API, also match the body its handler renders, as in [Rescuing errors](#rescuing-errors).

You SHOULD NOT write one for every persona that can't set the attribute. A persona who can't change the record at all, e.g. a User with someone else's post, is already turned away, and its context covers that.

```ruby
RSpec.describe "Posts" do
  describe "PATCH /posts/:id", :aggregate_failures do
    context "as a user", "with a post as the author" do
      let(:user) { create(:user) }

      let(:draft) { create(:post, author: user) }

      before { sign_in user }

      it "responds with bad request for featured" do
        expect {
          patch post_path(draft), params: { post: { featured: true } }
        }.not_to change { draft.reload.featured }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
```

## Authentication

Every action's `describe` block in the request spec has at least one scenario for an unauthenticated user. This catches an action that was left open by mistake, e.g. a `skip_before_action` that covers more actions than it means to.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/new" do
    context "when not signed in" do
      it "redirects to the sign in page" do
        get new_post_path

        expect(response).to redirect_to(new_user_session_path)
        expect(flash).to have_flash_alert("You need to sign in or sign up before continuing.")
      end
    end
  end
end
```

```ruby
RSpec.describe "Api::V1::Posts" do
  describe "GET /api/v1/posts" do
    context "without an access token" do
      it "responds with unauthorized" do
        get api_v1_posts_path

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

## Rescuing errors

Write at least one example in each request spec where the record isn't found, e.g. a post ID that doesn't exist. It covers every controller that finds a record from a param, e.g. `:id` or `:post_id`. A missing record gets the same response from any persona, so put it in any context that reaches the lookup. A Guest is usually sent to sign in first, so pick a signed-in persona.

Check what the client gets: `have_http_status(:not_found)`, or what the app's handler does, e.g. the redirect and the alert. For an API, also match the body its handler renders, as for any other JSON body. See [JSON](#json) and [Controllers and Routes: Rescuing errors](../../guide/controllers/#rescuing-errors). You MUST NOT check for an error that Rails or the app rescues, e.g. `raise_error(ActiveRecord::RecordNotFound)`. The client never sees the error, so the check passes whatever the response is.

Set `config.action_dispatch.show_exceptions = :rescuable` in `config/environments/test.rb`. Rails then turns each error it has a status for into that response, as it does in production, e.g. a 404 for `ActiveRecord::RecordNotFound`. Other errors still raise, so a bug still fails the spec. New apps since Rails 7.1 already have it. An older app might have `false` or `:none`, which raises every error instead.

```ruby
# config/environments/test.rb
Rails.application.configure do
  # ...
  config.action_dispatch.show_exceptions = :rescuable
end
```

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id", :aggregate_failures do
    context "as a user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "responds with not found for a missing post" do
        get post_path("missing")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

```ruby
RSpec.describe "Api::V1::Posts" do
  describe "GET /api/v1/posts/:id", :aggregate_failures do
    context "with an access token" do
      let(:headers) { { "Authorization" => "Bearer #{Rails.application.credentials.api_token}" } }

      it "responds with not found for a missing post" do
        get api_v1_post_path("missing"), headers: headers

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to match("error" => "Not found.")
      end
    end
  end
end
```

### Other services failing

When a controller rescues an action's error for the service failing, e.g. `ServiceError`, as in [Controllers and Routes: Other services failing](../../guide/controllers/#other-services-failing), stub the service to fail in the request spec with its helper from `spec/support`, e.g. `stub_newsletter_create_failure`, and check the redirect and the alert. Match the whole flash, so the spec fails if the alert ever includes the service's reply. Stub a timeout the same way, with `stub_newsletter_create_timeout`. See [Other Services: Helpers](../other-services/#helpers).

The handler also reports the error, so the example is tagged `:honeybadger` and checks the report. See [Honeybadger: Reporting errors](../gems/honeybadger/#reporting-errors).

```ruby
it "redirects with an alert when the newsletter service fails", :honeybadger do
  published_post = create(:post)
  stub_newsletter_create_failure

  post post_newsletter_path(published_post)

  expect(response).to redirect_to(post_path(published_post))
  expect(flash).to have_flash_alert("Newsletter could not be sent. Please try again later.")
  expect(Honeybadger).to have_received(:notify).with(
    an_instance_of(Posts::SendNewsletter::ServiceError),
    context: { post: published_post.to_honeybadger_context }
  )
end
```

## Shallow routes

A top-level controller for the actions on a single nested record, e.g. `CommentsController`, has its own request spec. It is named `"Comments"` and lives in `spec/requests/comments_spec.rb`.

## Request specs

Write a request spec for every controller. It tests each action the way a browser or API client uses it: the route, sign-in, authorisation, params and the response.

Put the spec in `spec/requests`, at the same path as the controller, e.g. `spec/requests/posts_spec.rb` for `PostsController` and `spec/requests/posts/comments_spec.rb` for `Posts::CommentsController`. Name the top-level `RSpec.describe` block after the controller's resource, e.g. `"Posts"` or `"Posts::Comments"`.

Inside it, write one `describe` block for each action, named with its route, in the same order as the controller. When an action responds to more than one format, write a `describe` block for each format, directly after the block for the default format. Then each action and format has its own place in the spec, and is easy to find from the controller. See [RESTful resources](#restful-resources) and [Response formats](#response-formats).

```ruby
class PostsController < ApplicationController
  # GET /posts
  # GET /posts.json
  def index
  end

  # GET /posts/:id
  def show
  end
end
```

```ruby
RSpec.describe "Posts" do
  describe "GET /posts" do
  end

  describe "GET /posts.json" do
  end

  describe "GET /posts/:id" do
  end
end
```

In each `describe` block, cover every path through the action: the happy path and every sad path. A path is anything the controller decides, e.g. each branch of an `if`, each redirect, and each error the controller rescues. The persona contexts already cover sign-in and authorisation. Inside each context, cover the paths that persona can take.

Write at least one example for each path, but not one for each reason the path is taken. Leave the detailed cases to the model, form and policy specs, e.g. each validation that can stop a post from saving. The request spec needs only one invalid post, e.g. one with a blank title, to show that the controller renders the form again. Then a controller change that drops a branch fails a request spec, and the request specs stay short.

```ruby
class PostsController < ApplicationController
  # POST /posts
  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to @post,
        notice: "Post was created."
    else
      render :new,
        status: :unprocessable_content
    end
  end
end
```

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

The paths include branches in the views the action renders, e.g. an `if` in a template or partial that shows a list or an empty message. Write at least one example for each branch, and check the body for what that branch shows.

```erb
<%# app/views/posts/index.html.erb %>
<% if @posts.any? %>
  <%= render @posts %>
<% else %>
  <p>No posts yet.</p>
<% end %>
```

```ruby
RSpec.describe "Posts" do
  describe "GET /posts", :aggregate_failures do
    context "as a user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "lists the posts" do
        create(:post, title: "Hello World")

        get posts_path

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_link("Hello World")
      end

      it "shows a message when there are no posts" do
        get posts_path

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_css("p", text: "No posts yet.")
      end
    end
  end
end
```

The POST and PATCH examples check that the record changed. The GET examples check that a page shows it. Between them, the GET examples SHOULD check each value a page shows at least once, e.g. on `GET /posts/:id`. Aim for every value to be covered somewhere, not for every combination of state and persona. Set the values in the example, and check each one with an element matcher. A value no page shows needs no GET example.

Some values only show once the record is in a state, e.g. the published date after an action publishes a post, or values a job or an action adds, e.g. after a post is sent to subscribers. Build the record in that state with the factory's trait, e.g. `create(:post, :published)`, and check those values. You don't need to set them in the example. Read them from the record through a format helper, e.g. `format_date(published_post.published_at)`. See [RSpec: Traits](../gems/rspec/#traits) and [RSpec: Values the example didn't set](../gems/rspec/#values-the-example-didnt-set).

You MUST NOT make the PATCH or POST request in the GET example to get the record into its state. The request already has its own example, and the trait shows the state the page is about.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/:id", :aggregate_failures do
    context "as a user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "shows the post" do
        draft = create(:post, title: "Hello World")

        get post_path(draft)

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_css("h1", text: "Hello World")
      end

      it "shows when a published post was published" do
        published_post = create(:post, :published)

        get post_path(published_post)

        expect(response).to have_http_status(:ok)

        expect(response.body).to have_css("p", text: "Published #{format_date(published_post.published_at)}")
      end
    end
  end
end
```

You MUST NOT stub the models, forms, actions, services or other classes the action calls, e.g. with `allow_any_instance_of(Post).to receive(:publish)` or `allow(Posts::ArchivePost).to receive(:call)`. Check what the action does instead: the records it changes, the response, the flash and the jobs it enqueues. Then the spec fails when any part of the action breaks, not only the controller's own lines. To test how the controller handles an action's `Error`, set up records that make the action fail for real. You MUST NOT test the action's argument checks, e.g. `unmodified:`, because every request that calls the action already runs them. See [Actions: Specs for callers](../actions/#specs-for-callers).

Check that the action enqueues each job, with its arguments, using `have_enqueued_job`. You MUST NOT run the job in the request spec. The job spec checks what the job does, and a feature spec runs it. See [Testing: Jobs](../jobs/).

```ruby
module Posts
  class PublicationsController < BaseController
    # POST /posts/:post_id/publication
    def create
      if @post.publish
        redirect_to @post,
          notice: "Post was published."
      else
        redirect_to @post,
          alert: "Post could not be published."
      end
    end
  end
end
```

```ruby
RSpec.describe "Posts::Publications" do
  describe "POST /posts/:post_id/publication", :aggregate_failures do
    # ...

    it "publishes the post" do
      draft = create(:post)

      expect {
        post post_publication_path(draft)
      }.to have_enqueued_job(NotifySubscribersJob).with(draft)

      expect(draft.reload).to be_published
      expect(response).to redirect_to(post_path(draft))
    end
  end
end
```

When the action calls another service during the request, stub only the HTTP request, and check that the action made it. Use the service's stub helpers from `spec/support`, and check the stub each one returns, e.g. `newsletter_request = stub_newsletter_create` then `expect(newsletter_request).to have_been_requested`. When a service's SDK has its own stubs, e.g. `stub_responses` in the AWS SDK, use them instead. See [Other Services](../other-services/).

See [RSpec: Request specs](../gems/rspec/#request-specs) for how to write the contexts inside each block.

## Feature specs

Write at least one feature spec for every controller that serves pages. Between them, cover the happy path of every HTML route in the controller. Request specs test each route on its own, but only a feature spec shows that a persona can reach the route through the app and finish the task. A route no scenario visits might have no link or button to it. This doesn't cover routes that only serve other formats, e.g. `GET /posts.json`, or controllers for an API. You can still write feature specs for them, as described in [RSpec: API endpoints](../gems/rspec/#api-endpoints).

A scenario can cover more than one controller, and one feature spec can cover routes from several. Start from the tasks each persona carries out, in persona rank order, then check that every route is covered. See [RSpec: Feature specs](../gems/rspec/#feature-specs) for how to write them.

```ruby
RSpec.feature "Post Writing" do
  scenario "Author edits and deletes a post" do
    # GIVEN I am signed in as an Author
    user = create(:user)
    sign_in user

    # AND I wrote a post
    draft = create(:post, author: user, title: "Hello World")

    # WHEN I edit my post
    visit post_path(draft)
    click_link "Edit"
    fill_in "Title", with: "Goodbye World"
    click_button "Update Post"

    # THEN I see the new title
    expect(page).to have_css("h1", text: "Goodbye World")

    # WHEN I delete my post
    click_button "Delete"

    # THEN it is no longer listed
    expect(page).not_to have_link("Goodbye World")
  end

  scenario "User writes a post" do
    # GIVEN I am signed in as a User
    user = create(:user)
    sign_in user

    # WHEN I start a new post from the list
    visit posts_path
    click_link "New post"

    # AND I save it
    fill_in "Title", with: "Hello World"
    click_button "Create Post"

    # THEN I see my post
    expect(page).to have_css("h1", text: "Hello World")
  end
end
```

The two scenarios visit all seven routes in `PostsController`: `show`, `edit`, `update` and `destroy` in the Author's, and `index`, `new` and `create` in the User's. The Author comes first, because the Authors group ranks above the Users.
