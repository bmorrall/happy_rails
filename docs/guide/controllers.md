---
title: Controllers and Routes
parent: The Guide
nav_order: 5
---

# Controllers and Routes

How requests are routed and handled.

## RESTful resources

Define the standard actions in this order:

1. `index`
2. `show`
3. `new`
4. `edit`
5. `create`
6. `update`
7. `destroy`

This is the order the Rails scaffold generator uses. Leave out any action the resource doesn't need, but keep the rest in this order.

Put a comment above each action with the route it handles, in the same format as the Rails scaffold generator, but with the param name (e.g. `:id`) in place of an example value.

The same order applies to the request specs in `spec/requests`. Name the top-level `RSpec.describe` block after the controller's resource (`"Posts"` for `PostsController`), then add one `describe` block for each route comment, in the same sequence as the controller. Name each `describe` block with its route, so a controller action and its specs are easy to match up.

```ruby
class PostsController < ApplicationController
  # GET /posts
  def index
  end

  # GET /posts/:id
  def show
  end

  # GET /posts/new
  def new
  end

  # GET /posts/:id/edit
  def edit
  end

  # POST /posts
  def create
  end

  # PATCH /posts/:id
  def update
  end

  # DELETE /posts/:id
  def destroy
  end
end
```

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

## Instance variables

Only set instance variables in an action, or in a callback whose name starts with `set_`, e.g. `set_post`. Don't set them in other private methods, in other callbacks, or in a memoised reader like `@post ||= Post.find(params[:id])`. Then you can find where every instance variable a view uses comes from: in the action itself, or in a `set_` callback listed at the top of the controller.

```ruby
class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy]

  # GET /posts
  def index
    @posts = Post.all
  end

  # GET /posts/:id
  def show
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end
end
```

## Success and failure

An action that changes a record, e.g. `create` or `update`, can succeed or fail. Write the happy case first, in an `if`, and the failure case in the `else`. Then each action reads the same way: what happens when it works, then what happens when it doesn't.

When the action fails and shows the form again, render it with `status: :unprocessable_entity`. The form then shows the errors, and Turbo knows the request failed. When there's no form to show, redirect instead, with a message that says what went wrong.

```ruby
class PostsController < ApplicationController
  # POST /posts
  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to @post, notice: "Post was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /posts/:id
  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

Publishing a post has no form, so a failure redirects back to the post.

```ruby
module Posts
  class PublicationsController < BaseController
    # POST /posts/:post_id/publication
    def create
      if @post.publish
        redirect_to @post, notice: "Post was published."
      else
        redirect_to @post, alert: "Post could not be published."
      end
    end
  end
end
```

## Flash messages

Pick one pattern for flash messages in each app, and use it in every controller. The guide doesn't choose the wording for you. The Rails scaffold's `"Post was successfully created."` works, and so does a shorter `"Post was created."`. What matters is that every message follows the same pattern, so the app reads as one piece and the request specs know what to expect.

Use the same flash key for every success message, and the same one for every failure. Rails' `notice` and `alert` are the easy choice, because the scaffold's layout and Devise already use them.

Set a flash when the action redirects, so the user knows what happened. Don't set one when the action renders the form again. The form's errors already say what went wrong.

This guide uses `notice: "Post was created."` for success, and `alert: "Post could not be published."` for a failure that redirects.

## Nested resources

Put controllers for a nested resource in a module named after the parent controller. Comments on a post go in `Posts::CommentsController`, in `app/controllers/posts/comments_controller.rb`. In the routes, put the nested resources in a `scope module:` block inside the parent resource.

```ruby
resources :posts do
  scope module: :posts do
    resources :comments, only: %i[index create]
  end
end
```

Each module has a `BaseController` that the nested controllers inherit from. It loads the parent record and checks that the current user can see it, so the nested controllers don't repeat that work. The base controller has no actions of its own, and no routes point to it.

The check on the parent doesn't count as the action's own check. Being able to see a post doesn't mean a user may comment on it, so each nested action still starts with its own authorisation check. For how to do this with Pundit, see [Pundit: Nested resources](../gems/pundit/#nested-resources).

```ruby
module Posts
  class BaseController < ApplicationController
    before_action :set_post

    private

    def set_post
      @post = Post.find(params[:post_id])
      # Check the current user can see @post
    end
  end
end
```

```ruby
module Posts
  class CommentsController < BaseController
    # GET /posts/:post_id/comments
    def index
      @comments = @post.comments
    end

    # POST /posts/:post_id/comments
    def create
    end
  end
end
```

Nested controllers follow the same action order and route comments as any other controller. Name the request spec after the full controller name (`"Posts::Comments"`) and put it in `spec/requests/posts/comments_spec.rb`.

```ruby
RSpec.describe "Posts::Comments" do
  describe "GET /posts/:post_id/comments" do
  end

  describe "POST /posts/:post_id/comments" do
  end
end
```

## Non-CRUD actions

Avoid adding custom actions to a resource controller. Most custom actions are a change to the resource that can be modelled as a resource of its own.

Make the action a new controller with a `create` action instead. Use the same module and `BaseController` pattern as a nested resource. To publish a post, add `Posts::PublicationsController` in `app/controllers/posts/publications_controller.rb`, rather than a `publish` action on `PostsController`.

```ruby
resources :posts do
  scope module: :posts do
    resource :publication, only: :create
  end
end
```

```ruby
module Posts
  class PublicationsController < BaseController
    # POST /posts/:post_id/publication
    def create
    end
  end
end
```

```ruby
RSpec.describe "Posts::Publications" do
  describe "POST /posts/:post_id/publication" do
  end
end
```

### Custom actions

If you do add custom actions to a controller, put them below the standard actions, in alphabetical order. Give each one a route comment, and add its `describe` blocks to the request spec in the same order.

```ruby
class PostsController < ApplicationController
  # GET /posts/:id
  def show
  end

  # DELETE /posts/:id
  def destroy
  end

  # POST /posts/:id/duplicate
  def duplicate
  end

  # GET /posts/:id/preview
  def preview
  end
end
```

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

Each controller has a default format that fits what it's for: HTML for pages, JSON for APIs, and so on. Leave the default format out of route comments and `describe` blocks.

When an action also responds to another format, add a second route comment with the format extension, below the default route. Add a matching `describe` block in the request spec, directly after the block for the default format.

```ruby
class PostsController < ApplicationController
  # GET /posts
  # GET /posts.json
  def index
  end

  # GET /posts/:id
  # GET /posts/:id.json
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

  describe "GET /posts/:id.json" do
  end
end
```

### Turbo Streams

Treat a Turbo Stream response as an extra on top of HTML, not a replacement. Every action that responds with a Turbo Stream also keeps its HTML response, usually the redirect from the scaffold. Put `format.html` first in the `respond_to` block. Then the action still works without JavaScript, and for any request that doesn't ask for a stream.

Turbo asks for a stream with the `Accept` header, not a format extension, so the URL doesn't change. Don't add a second route comment for it. In the request spec, add a `context "with a Turbo Stream"` inside the route's `describe` block, and send the `Accept` header in that context.

Turbo Drive and Turbo Frames request plain HTML, so they need nothing extra.

```ruby
module Posts
  class CommentsController < BaseController
    # POST /posts/:post_id/comments
    def create
      @comment = @post.comments.build(comment_params)

      respond_to do |format|
        if @comment.save
          format.html { redirect_to @post, notice: "Comment was created." }
          format.turbo_stream
        else
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end
  end
end
```

```ruby
RSpec.describe "Posts::Comments" do
  describe "POST /posts/:post_id/comments" do
    let(:published_post) { create(:post, published_at: Time.current) }

    it "redirects to the post" do
      post post_comments_path(published_post), params: { comment: { body: "Hello" } }

      expect(response).to redirect_to(post_path(published_post))
      expect(flash.to_hash).to match("notice" => "Comment was created.")
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
```

## Strong parameters

If you use Pundit, put the main app's permitted attributes in the policy instead, and have `post_params` call Pundit. See [Pundit: Strong parameters](../gems/pundit/#strong-parameters). The `require` and `permit` rules below are for apps without Pundit, and for other APIs in an app with Pundit.

Nest a resource's params under its singular name: `post` for `PostsController`, `comment` for `Posts::CommentsController`. This is the key Rails form helpers use for a model, so `form_with model: @post` sends the right params with no extra setup.

Read the params in a private method named after the resource, e.g. `post_params`. Use `params.require` with the singular name, then `permit` each attribute the action may change. Never use `permit!` or pass through a whole hash. A new column then can't be set from a request until you add it to the list.

```ruby
class PostsController < ApplicationController
  # POST /posts
  def create
    @post = Post.new(post_params)
    # ...
  end

  # PATCH /posts/:id
  def update
    if @post.update(post_params)
      # ...
    end
  end

  private

  def post_params
    params.require(:post).permit(:title, :body)
  end
end
```

Send params in the request spec the same way, nested under the singular name.

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

### Different params per action

Sometimes `create` and `update` accept different attributes, e.g. a slug that can only be set when the post is created. In that case, replace `post_params` with one method per action, named with a `_for_<action>` suffix: `post_params_for_create` and `post_params_for_update`. Don't keep a plain `post_params` next to them, or it isn't clear which one a new action should use.

The suffix keeps every params method for a resource starting with `post_params`, so they sit together and are easy to find.

Write out each list in full, even if some attributes repeat. Don't build one list from another. Then you can see exactly what each action accepts.

```ruby
class PostsController < ApplicationController
  # POST /posts
  def create
    @post = Post.new(post_params_for_create)
    # ...
  end

  # PATCH /posts/:id
  def update
    if @post.update(post_params_for_update)
      # ...
    end
  end

  private

  def post_params_for_create
    params.require(:post).permit(:title, :body, :slug)
  end

  def post_params_for_update
    params.require(:post).permit(:title, :body)
  end
end
```

## Authentication

Always use a gem or a built-in Rails authentication method to authenticate requests, e.g. `http_basic_authenticate_with`. Never write a custom solution. Authentication is easy to get subtly wrong, and well-used code has already dealt with the edge cases.

Put the authentication check in `ApplicationController`, so every controller requires it by default. A new controller is then never left open by mistake. If a page must be public, skip the check in that controller with `skip_before_action`, and list only the actions that need it.

Use [Devise](../gems/devise/) for users who sign in. It is the default choice for any app with user accounts.

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end
```

```ruby
class PostsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]
end
```

An API that authenticates differently has its own base controller, e.g. `Api::V1::BaseController`. Put the check in the top-most controller that every API controller inherits from, not in each API controller.

When you use a built-in method, follow the Rails best practices for it:

- Keep usernames, passwords and tokens in Rails credentials or environment variables. Never write them in the code.
- Compare secrets with `ActiveSupport::SecurityUtils.secure_compare`, not `==`. A plain comparison can leak the secret through timing attacks.
- Only accept credentials over HTTPS, e.g. with `config.force_ssl = true` in production.

```ruby
module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate

      private

      def authenticate
        authenticate_or_request_with_http_token do |token, _options|
          ActiveSupport::SecurityUtils.secure_compare(token, Rails.application.credentials.api_token)
        end
      end
    end
  end
end
```

```ruby
module Api
  module V1
    class PostsController < BaseController
    end
  end
end
```

Every action's `describe` block in the request spec has at least one scenario for an unauthenticated user. This catches an action that was left open by mistake, e.g. a `skip_before_action` that covers more actions than it should.

```ruby
RSpec.describe "Posts" do
  describe "GET /posts/new" do
    context "when not signed in" do
      it "redirects to the sign in page" do
        get new_post_path

        expect(response).to redirect_to(new_user_session_path)
        expect(flash.to_hash).to match("alert" => "You need to sign in or sign up before continuing.")
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

When you rescue an error with `rescue_from`, pass `with:` and the name of a private method. Start the name with `handle_`, then add the error's name without the `Error` suffix, e.g. `handle_record_not_found` for `ActiveRecord::RecordNotFound`. Don't pass a block.

A named method is easy to find, and every handler starts the same way. A subclass can also override it to handle the error its own way, and call `super` for the default. You can't do that with a block. See [Pundit: Unauthorised requests](../gems/pundit/#unauthorised-requests) for an example.

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  private

  def handle_record_not_found
    # ...
  end
end
```

## Authorization

Use [Pundit](../gems/pundit/) to authorise requests. It is the default choice for any app with user accounts. The rules below apply whichever gem you use. See [Pundit: Controllers](../gems/pundit/#controllers) for how to write each check with Pundit.

Start every action with an authorisation check on its first line, before the action loads more data, changes a record or renders anything. Then the check is the first thing you read in each action, and no work happens for a user who isn't allowed to do it.

Leave a blank line after the check, so it stands apart from the rest of the action. If the check is the only line, there's nothing to separate.

```ruby
class PostsController < ApplicationController
  # PATCH /posts/:id
  def update
    authorize @post

    # ...
  end
end
```

Make every controller require the check by default, so a missing check fails in your specs rather than leaving the action open. Set this up once in `ApplicationController`, not in each controller. See [Pundit: Setup](../gems/pundit/#setup).

If an action really needs no check, opt out on the action's first line, not with a skip at the top of the controller. The opt-out then sits where the check would be, so anyone reading the action can see it was left out on purpose. A new action added to the controller still needs its own check.

## Routes

Rails works best with RESTful resources, so keep routes RESTful whenever you can. The sections above cover how to turn a custom action into a resource of its own.

### Only route the actions you have

Give every `resources` and `resource` call an `only:` list that matches the controller's actions. Then `rails routes` lists only routes that work, and no route points at a missing action. Use `only:`, not `except:`. A new action can't be reached until you add it to the list, just like a new attribute in strong parameters.

Leave `only:` off only when the controller has all seven standard actions.

```ruby
resources :posts, only: %i[index show]
```

### Use the routing helpers

Declare routes with `resources`, `resource`, `namespace` and `root`. Don't write paths by hand, e.g. `get "posts/:id/preview", to: "posts#preview"`. The helpers keep the URL, the controller and the path helper names in step.

When a controller does need a custom action, add it in a `member` or `collection` block.

```ruby
resources :posts, only: %i[show destroy] do
  member do
    post :duplicate
    get :preview
  end
end
```

### Singular resources

Use `resource`, not `resources`, when there is only one of something, e.g. a post's publication or the current user's profile. The route has no `:id`, and the controller is still named in the plural.

```ruby
resource :profile, only: %i[show edit update]
```

```ruby
class ProfilesController < ApplicationController
  # GET /profile
  def show
  end
end
```

### Namespaces

Use `namespace` when both the URL and the controller module change, e.g. an API or an admin area. Use `scope module:` when only the module changes, as with nested resources.

```ruby
namespace :api do
  namespace :v1 do
    resources :posts, only: %i[index show]
  end
end
```

```ruby
module Api
  module V1
    class PostsController < BaseController
      # GET /api/v1/posts
      def index
      end
    end
  end
end
```

### Shallow routes

Nest resources one level deep at most. Don't use `shallow: true`. A shallow member route has no `:post_id`, so `Posts::BaseController` can't load the post.

Instead, declare the actions that don't need the parent as a top-level resource of their own. Keep the actions that need the post, such as `index` and `create`, in `Posts::CommentsController`. Put the actions on a single comment in `CommentsController`.

```ruby
resources :posts do
  scope module: :posts do
    resources :comments, only: %i[index new create]
  end
end

resources :comments, only: %i[show edit update destroy]
```

```ruby
class CommentsController < ApplicationController
  # GET /comments/:id
  def show
  end

  # DELETE /comments/:id
  def destroy
  end
end
```

Each controller then loads its records the same way every time. Its request spec is named `"Comments"` and lives in `spec/requests/comments_spec.rb`.

### Link with path helpers

Build links and redirects with path helpers or records, e.g. `post_path(@post)` or `redirect_to @post`. Never write a URL as a string. If a route changes, the helper changes with it, and a helper that no longer exists raises an error instead of sending users to a dead page.

```ruby
redirect_to post_comments_path(@post)
```

## Testing

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
      redirect_to @post, notice: "Post was created."
    else
      render :new, status: :unprocessable_entity
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

        expect(response.body).to include("Hello World")
      end

      it "shows a message when there are no posts" do
        get posts_path

        expect(response).to have_http_status(:ok)

        expect(response.body).to include("No posts yet.")
      end
    end
  end
end
```

See [RSpec: Request specs](../gems/rspec/#request-specs) for how to write the contexts inside each block.

Write at least one feature spec for every controller that serves pages. Between them, its scenarios must cover the happy path of every HTML route in the controller. Request specs test each route on its own, but only a feature spec shows that a persona can reach the route through the app and finish the task. A route no scenario visits may have no link or button to it. This doesn't cover routes that only serve other formats, e.g. `GET /posts.json`, or controllers for an API. You can still write feature specs for them, as described in [RSpec: API endpoints](../gems/rspec/#api-endpoints).

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
    expect(page).to have_content("Goodbye World")

    # WHEN I delete my post
    click_button "Delete"

    # THEN it is no longer listed
    expect(page).not_to have_content("Goodbye World")
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
    expect(page).to have_content("Hello World")
  end
end
```

The two scenarios visit all seven routes in `PostsController`: `show`, `edit`, `update` and `destroy` in the Author's, and `index`, `new` and `create` in the User's. The Author comes first, because the Authors group ranks above the Users.
