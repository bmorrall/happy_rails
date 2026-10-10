---
title: Controllers and Routes
parent: The Guide
nav_order: 9
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

See [Testing: Controllers and Routes](../../testing/controllers/#restful-resources) for the request specs.

## Instance variables

Only set instance variables in an action, or in a callback whose name starts with `set_`, e.g. `set_post`. Don't set them in other private methods, in other callbacks, or in a memoised reader like `@post ||= Post.find(params[:id])`. Then you can find where every instance variable a view uses comes from: in the action itself, or in a `set_` callback listed at the top of the controller.

```ruby
class PostsController < ApplicationController
  before_action :set_post,
    only: %i[show edit update destroy]

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

## Values from services

When a page shows a value read from another service, e.g. a newsletter's open rate, read it in the action or a `set_` callback, before the view renders. Call the service from a private method, and assign the value to an instance variable.

The action then shows every request the page makes. An error from the service is raised before any of the page renders, so the controller can rescue it.

```ruby
class PostsController < ApplicationController
  # GET /posts/:id
  def show
    @newsletter_stats = fetch_newsletter_stats
  end

  private

  def fetch_newsletter_stats
    NewsletterClient.new.fetch_stats(@post.newsletter_id) if @post.newsletter_id?
  end
end
```

A helper method may give the value to the view, e.g. for a partial. It only returns the value the action read, and never calls the service:

```ruby
class PostsController < ApplicationController
  helper_method :newsletter_stats

  # ...

  private

  # Don't do this
  def newsletter_stats
    @newsletter_stats ||= NewsletterClient.new.fetch_stats(@post.newsletter_id)
  end
end
```

When a list shows a value for each record, read them all in one call, e.g. `NewsletterClient#fetch_all_stats`. Give the view a helper method that looks up one record's value, e.g. `newsletter_stats_for(post)`. Never make one request for each record.

See [Patterns: Values from Services](../../patterns/values-from-services/) for examples and other options.

## Success and failure

An action that changes a record, e.g. `create` or `update`, can succeed or fail. Write the happy case first, in an `if`, and the failure case in the `else`. Then each action reads the same way: what happens when it works, then what happens when it doesn't.

When the action fails and shows the form again, render it with `status: :unprocessable_entity`. The form then shows the errors, and Turbo knows the request failed. When there's no form to show, redirect instead, with a message that says what went wrong.

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
        status: :unprocessable_entity
    end
  end

  # PATCH /posts/:id
  def update
    if @post.update(post_params)
      redirect_to @post,
        notice: "Post was updated."
    else
      render :edit,
        status: :unprocessable_entity
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

When the action submits a [form](../forms/) and needs the result, assign the result of `submit` in the `if`, in brackets, e.g. `if (post = @create_post_form.submit)`. Use it only in the happy case. When it doesn't need the result, don't assign it, e.g. `if @archive_post_form.submit`. The brackets show the `=` is meant, not a typo for `==`.

`submit` returns `false` when it fails. Assigned in the `if`, the result is only used once you know it worked, so a failed submit can't reach code that expects the resource.

```ruby
class PostsController < ApplicationController
  # POST /posts
  def create
    @create_post_form = CreatePostForm.new(Post.new, current_user, post_params)

    if (post = @create_post_form.submit)
      redirect_to post,
        notice: "Post was created."
    else
      render :new,
        status: :unprocessable_entity
    end
  end
end
```

```ruby
# Don't do this
result = @share_post_form.submit
@preview_url = preview_post_url(result.post, token: result.token)

if result
  # ...
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

Nested controllers follow the same action order and route comments as any other controller.

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

### Custom actions

If you do add custom actions to a controller, put them below the standard actions, in alphabetical order. Give each one a route comment.

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

## Response formats

Each controller has a default format that fits what it's for: HTML for pages, JSON for APIs, and so on. Leave the default format out of route comments.

When an action also responds to another format, add a second route comment with the format extension, below the default route.

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

See [Testing: Controllers and Routes](../../testing/controllers/#response-formats) for the request specs.

### Turbo Streams

Treat a Turbo Stream response as an extra on top of HTML, not a replacement. Every action that responds with a Turbo Stream also keeps its HTML response, usually the redirect from the scaffold. Put `format.html` first in the `respond_to` block. Then the action still works without JavaScript, and for any request that doesn't ask for a stream.

Turbo asks for a stream with the `Accept` header, not a format extension, so the URL doesn't change. Don't add a second route comment for it.

Turbo Drive and Turbo Frames request plain HTML, so they need nothing extra.

```ruby
module Posts
  class CommentsController < BaseController
    # POST /posts/:post_id/comments
    def create
      @comment = @post.comments.build(comment_params)

      respond_to do |format|
        if @comment.save
          format.html do
            redirect_to @post,
              notice: "Comment was created."
          end
          format.turbo_stream
        else
          format.html do
            render :new,
              status: :unprocessable_entity
          end
        end
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
  skip_before_action :authenticate_user!,
    only: %i[index show]
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

See [Testing: Controllers and Routes](../../testing/controllers/#authentication) for the request specs.

## Rescuing errors

When you rescue an error with `rescue_from`, pass `with:` and the name of a private method. Start the name with `handle_`, then add the error class's name in snake case, e.g. `handle_record_not_found` for `ActiveRecord::RecordNotFound` and `handle_not_authorized_error` for `Pundit::NotAuthorizedError`. Keep the `Error` suffix, so the name says it handles a failure. Don't pass a block.

A named method is easy to find, and every handler starts the same way. A subclass can also override it to handle the error its own way, and call `super` for the default. You can't do that with a block. See [Pundit: Unauthorised requests](../gems/pundit/#unauthorised-requests) for an example.

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound,
    with: :handle_record_not_found

  private

  def handle_record_not_found
    # ...
  end
end
```

Use `rescue_from` only for errors that aren't part of the app's normal flow, e.g. a record that isn't found, or a request the user isn't allowed to make. When an error is an outcome the app expects, handle it where the work is done, in a form or a job. Either one can recover from the error, or add the error. A form adds it to its errors and returns `false`, so the controller takes its normal failure path. A job adds it to the record it works on, e.g. it marks a subscription as failed when its payment fails. The action then shows every outcome the user can expect as a normal path, and its request spec covers each one.

```ruby
class NotifySubscribersJob < ApplicationJob
  # ...

  def perform(post)
    NewsletterClient.new.deliver(post)
  rescue NewsletterClient::DeliveryError
    post.update!(newsletter_status: :failed)
  end
end
```

### Other services failing

When a controller calls an [action](../actions/) that calls another service, the service can fail, e.g. it returns a 500 or times out. That isn't part of the app's normal flow. The user didn't cause it, and can't fix it by changing what they submitted. Give the action an error class for this cause, e.g. `Posts::SendNewsletter::ServiceError`, as in [Actions: Error handling](../actions/#error-handling). Rescue it with `rescue_from`, and name the handler after the action and the error, e.g. `handle_send_newsletter_service_error`. Errors the user or a developer caused, e.g. invalid data, still belong in a form, as above.

Always rescue `ServiceError` itself, even when you also rescue its subclasses. It is the catch-all: it covers every way the service can fail, including a cause added later. A subclass can have its own handler, e.g. when an API returns another status for a timeout, as below.

In the handler, redirect with an alert. Write the alert as fixed text, and never show the error's message. It may hold the other service's reply, or details about your systems.

```ruby
module Posts
  class NewslettersController < BaseController
    rescue_from Posts::SendNewsletter::ServiceError,
      with: :handle_send_newsletter_service_error

    # POST /posts/:post_id/newsletter
    def create
      # ...

      Posts::SendNewsletter.call(@post)

      redirect_to post_path(@post),
        notice: "Newsletter was sent."
    end

    private

    def handle_send_newsletter_service_error
      redirect_to post_path(@post),
        alert: "Newsletter could not be sent. Please try again later."
    end
  end
end
```

An API controller renders the error instead, with a 5xx status, so the client knows its request wasn't the problem. Render `ServiceError` with `:bad_gateway` (502), which says the other service failed.

When the client should get another status for one cause, give the action a subclass of `ServiceError` for it, e.g. `Posts::SendNewsletter::TimeoutError`, and rescue it with its own handler. Use `:gateway_timeout` (504) when the service took too long to reply. Use `:service_unavailable` (503) when the service can't be reached for now, e.g. it is down for maintenance. A 503 tells the client to try again later.

Declare the subclass's `rescue_from` after the one for `ServiceError`. Rails checks the handlers from the last one declared to the first, so the subclass's handler must come last to be found first.

```ruby
rescue_from Posts::SendNewsletter::ServiceError,
  with: :handle_send_newsletter_service_error
rescue_from Posts::SendNewsletter::TimeoutError,
  with: :handle_send_newsletter_timeout_error

# ...

private

def handle_send_newsletter_service_error
  render json: { error: "Newsletter could not be sent. Please try again later." },
    status: :bad_gateway
end

def handle_send_newsletter_timeout_error
  render json: { error: "Newsletter could not be sent. Please try again later." },
    status: :gateway_timeout
end
```

See [Testing: Controllers and Routes](../../testing/controllers/#other-services-failing) for the request specs.

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

Each controller then loads its records the same way every time.

### Link with path helpers

Build links and redirects with path helpers or records, e.g. `post_path(@post)` or `redirect_to @post`. Never write a URL as a string. If a route changes, the helper changes with it, and a helper that no longer exists raises an error instead of sending users to a dead page.

```ruby
redirect_to post_comments_path(@post)
```

## Testing

See [Testing: Controllers and Routes](../../testing/controllers/).
