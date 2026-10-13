---
title: Pundit
parent: Gems
grand_parent: The Guide
nav_order: 4
---

# Pundit

Authorisation with [Pundit](https://github.com/varvet/pundit).

## Setup

Put Pundit's setup in a `PunditAuthorization` concern, in `app/controllers/concerns/pundit_authorization.rb`, and include it in `ApplicationController`. All of the setup is then in one file. See [Directory Layout: Concerns](../../directory-layout/#gem-setup).

The concern includes Pundit and adds its `verify_authorized` check, so every controller requires it by default. It also adds `verify_policy_scoped` to every `index` action, so an index that lists records without its policy's scope fails too. See [Scopes](#scopes). It raises an error when an action finishes without calling `authorize`, so a missing check fails in your specs rather than leaving the action open. See [Controllers](#controllers) below for how each action calls `authorize` or opts out, and [Unauthorised requests](#unauthorised-requests) for what happens when a check fails.

Leave out Devise's own controllers, because you can't add checks to their actions.

```ruby
module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    after_action :verify_authorized,
      unless: :devise_controller?
    after_action :verify_policy_scoped,
      only: :index

    rescue_from Pundit::NotAuthorizedError,
      with: :handle_not_authorized_error
  end

  private

  def handle_not_authorized_error
    redirect_to root_url,
      alert: "You are not authorized to perform this action."
  end
end
```

```ruby
class ApplicationController < ActionController::Base
  include PunditAuthorization

  before_action :authenticate_user!
end
```

## Policies

Write one policy for each model, named after it, e.g. `PostPolicy` in `app/policies/post_policy.rb`. Inherit it from `ApplicationPolicy`.

Generate `ApplicationPolicy` with `bin/rails generate pundit:install`, and keep its defaults. Every permission returns `false`, so a policy only allows what it defines. `new?` calls `create?`, and `edit?` calls `update?`. Leave `new?` and `edit?` out of a policy unless they differ from `create?` and `update?`.

A permission reads the user's roles and the record. List the roles in rank order, as in [Principles: Keep the ranks](../../principles/#keep-the-ranks), with a role on the record last.

```ruby
class PostPolicy < ApplicationPolicy
  def update?
    user.app_admin? ||
      record.user_is_copy_editor?(user) ||
      record.user_is_author?(user) ||
      record.user_is_coauthor?(user)
  end
end
```

### Roles on the record

Check a role on the record with the model's `user_is_<role>?` method, e.g. `record.user_is_author?(user)`. Write the role's condition in the model, not in the policy. See [Models: User access](../../models/#user-access). Check a role on the whole app on the user when it covers every record, e.g. `user.app_admin?`. When it only covers some records, check it through the model too, e.g. `record.user_is_copy_editor?(user)`, which also checks that the post is a draft.

Then each role is written once, and the policy reads as a list of who can do it.

A view checks some permissions for every record in a list, e.g. `show?` for each post's link. You SHOULD NOT run a `where` query in those permissions, e.g. `user.coauthorships.where(post_id: record.id).exists?`. A `where` always runs a new query, even on a preloaded association, so the list runs one for every post. Read loaded values instead, as in [Models: User access](../../models/#user-access).

When one of those permissions checks whether a record has any associated records, e.g. `record.comments.any?`, you SHOULD add a counter cache to the association, e.g. `belongs_to :post, counter_cache: true` on `Comment`, with a `comments_count` column on `posts`. Then `any?` reads the count from the post, with no query. Call it without a block. With a block, `any?` loads the records.

A view checks some permissions for every record in a list, e.g. `show?` for each post's link. You SHOULD NOT add conditions to those permissions beyond what they need. Each condition runs once for every record on the page, and one that reads an association needs a preload to stay cheap. A list loaded through the policy scope only holds records the user can see, so it rarely needs to check `show?` for each one.

### Guests

`ApplicationController` signs in every user before the action runs, so most permissions can assume there is a user. Only check for a missing user in a permission for an action a Guest can reach, e.g. one that skips `authenticate_user!`.

Check with a guard clause, before the role checks. Without it, the role checks raise `NoMethodError` on `nil`, instead of forbidding the Guest.

```ruby
class PostPolicy < ApplicationPolicy
  def show?
    return true if record.published?
    return false unless user

    user.app_admin? ||
      user.publishing_manager? ||
      record.user_is_copy_editor?(user) ||
      record.user_is_author?(user) ||
      record.user_is_coauthor?(user)
  end
end
```

### Parent records

Put the permission for a nested resource's action in the parent's policy, when the check needs the parent. Name it after the task, and put it under the heading for its feature or association, as in [Layout](#layout). For example, publishing a post is `PostPolicy#publish?` under `### Publishing ###`, and commenting on a post is `PostPolicy#create_comment?` under `### Comments ###`. You MUST NOT write a policy for the nested resource for these checks, e.g. `Posts::PublicationPolicy`.

Then the post's policy lists everything a user can do with a post, and each check reads the post it needs.

```ruby
class PostPolicy < ApplicationPolicy
  ### Comments ###

  def create_comment?
    record.published?
  end

  ### Publishing ###

  def publish?
    user.app_admin? || user.publishing_manager?
  end
end
```

In the controller, pass the parent and the permission to `authorize`.

```ruby
module Posts
  class PublicationsController < BaseController
    # POST /posts/:post_id/publication
    def create
      authorize @post, :publish?

      # ...
    end
  end
end
```

A check on the nested record itself stays in its own policy, e.g. `CommentPolicy#destroy?` for `authorize @comment` in `Posts::CommentsController#destroy`.

### Layout

Lay out every policy the same way, so you know where to find a rule:

1. The `Scope` class.
2. A permission for each action, in the same order as the controller: `index?`, `show?`, `new?`, `edit?`, `create?`, `update?`, `destroy?`, then any custom actions in alphabetical order. See [Controllers: RESTful resources](../../controllers/#restful-resources).
3. Other permission checks, under a comment heading named after what they cover. Use the association for checks on an association, e.g. `### Comments ###`, and the feature for checks on a feature, e.g. `update_published?` under `### Publishing ###`. Name a feature's heading after the model's `concerning` block for it, e.g. `concerning :Publishing` in `Post`, so the policy and the model group a feature the same way. See [Models: Layout](../../models/#layout). Put the headings in alphabetical order.
4. The permitted attributes methods, under `### Permitted Attributes ###`. Always put this heading last. See [Strong parameters](#strong-parameters).

Keeping an association's checks together shows everything a user can do with it, e.g. who can comment on a post and who can approve the comments.

Leave out any permission or heading the policy doesn't need. Private methods go last, after `private`.

```ruby
class PostPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # ...
    end
  end

  def index?
    # ...
  end

  def show?
    # ...
  end

  def create?
    # ...
  end

  def update?
    # ...
  end

  ### Comments ###

  def create_comment?
    # ...
  end

  def approve_comments?
    # ...
  end

  ### Publishing ###

  def update_published?
    user.app_admin? || user.publishing_manager?
  end

  ### Permitted Attributes ###

  def permitted_attributes
    attributes = [:title, :body]
    attributes << :published if update_published?
    attributes
  end
end
```

## Scopes

A policy's scope SHOULD list exactly the records `show?` allows. Then a list never shows a post the user can't open, and never hides one they can. Use the same scope for every list of the model.

How a list differs from `show?` is up to the app. An app MAY leave records out of its lists that `show?` still allows, e.g. archived posts, which a reader can still open from a link.

When the scope matches `show?`, write `resolve` with the same checks, in the same order. Filter by a role on the record with the model's `for_user_as_<role>` scope, e.g. `scope.for_user_as_author(user)`, as in [Roles on the record](#roles-on-the-record).

Return a relation, so the list is one query and the controller can still order and paginate it. You MUST NOT filter the records in Ruby, e.g. `scope.select { |post| post.published? }`.

```ruby
class PostPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.published unless user
      return scope.all if user.app_admin? || user.publishing_manager?

      scope.published
        .or(scope.for_user_as_copy_editor(user))
        .or(scope.for_user_as_author(user))
        .or(scope.for_user_as_coauthor(user))
    end
  end

  def show?
    return true if record.published?
    return false unless user

    user.app_admin? ||
      user.publishing_manager? ||
      record.user_is_copy_editor?(user) ||
      record.user_is_author?(user) ||
      record.user_is_coauthor?(user)
  end
end
```

### Lists

Load every list in a controller through `policy_scope`, after `authorize`. Pass the model for an index, e.g. `policy_scope(Post)`. Preload the associations its permission checks read, e.g. `policy_scope(Post).includes(:coauthorships)`, as in [Models: User access](../../models/#user-access). Pass the association for a nested list, e.g. `policy_scope(@post.comments)`, and Pundit uses `CommentPolicy::Scope`.

The `PunditAuthorization` concern checks that every `index` action calls `policy_scope`. If an index lists no records, call `skip_policy_scope` after `authorize`. You MUST NOT use `skip_after_action :verify_policy_scoped`, for the same reason as `verify_authorized` in [Controllers](#controllers).

```ruby
class PostsController < ApplicationController
  # GET /posts
  def index
    authorize Post

    @posts = policy_scope(Post).includes(:coauthorships)
  end
end
```

### Single records

Load a single record with `find`, then `authorize` it, as in [Controllers](#controllers). A user who can't see it gets the redirect in [Unauthorised requests](#unauthorised-requests).

An app MAY load single records through the scope instead, e.g. `@post = policy_scope(Post).find(params[:id])`. A record the user can't see then returns 404 Not Found, as if it didn't exist. Pick one way for the whole app.

## Controllers

Call `authorize` on the first line of every action, as in [Controllers: Authorization](../../controllers/#authorization). Pass the record when the action has one, and the class when it doesn't, e.g. in `index`, `new` and `create`.

```ruby
class PostsController < ApplicationController
  # GET /posts
  def index
    authorize Post

    @posts = policy_scope(Post)
  end

  # GET /posts/:id
  def show
    authorize @post
  end

  # POST /posts
  def create
    authorize Post

    @post = Post.new(post_params)
    # ...
  end

  # PATCH /posts/:id
  def update
    authorize @post

    # ...
  end
end
```

If an action really needs no check, call `skip_authorization` on its first line. You MUST NOT use `skip_after_action :verify_authorized` at the top of the controller, because it also covers any action added later.

```ruby
class PagesController < ApplicationController
  skip_before_action :authenticate_user!,
    only: :about

  # GET /about
  def about
    skip_authorization
  end
end
```

### Nested resources

A nested resource's `BaseController` checks that the user can see the parent record. See [Controllers: Nested resources](../../controllers/#nested-resources). You MUST NOT use `authorize` for this check. It marks the request as authorised, so `verify_authorized` would pass for every nested action, and an action with no check of its own would be left open.

Use `pundit.authorize` instead, with the `query:` and `policy_class:` keywords. It raises an error like `authorize` does when the user can't see the post, but it doesn't mark the request as authorised. Each nested action still has to call `authorize` itself, or `verify_authorized` fails. When its check needs the post, pass the post and the permission, e.g. `authorize @post, :create_comment?`. See [Parent records](#parent-records). `pundit.authorize` needs Pundit 2.4 or later.

```ruby
module Posts
  class BaseController < ApplicationController
    before_action :set_post

    private

    def set_post
      @post = Post.find(params[:post_id])
      pundit.authorize(@post, query: :show?, policy_class: PostPolicy)
    end
  end
end
```

```ruby
module Posts
  class CommentsController < BaseController
    # GET /posts/:post_id/comments
    def index
      authorize Comment

      @comments = policy_scope(@post.comments)
    end

    # POST /posts/:post_id/comments
    def create
      authorize @post, :create_comment?
    end
  end
end
```

### Unauthorised requests

When a check fails, Pundit raises `Pundit::NotAuthorizedError`. Rescue it in the `PunditAuthorization` concern with a `handle_not_authorized_error` method, as in [Controllers: Rescuing errors](../../controllers/#rescuing-errors). Redirect to the root page with an alert. The root page is one every user can see, so the redirect never fails its own check.

```ruby
module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    # ...

    rescue_from Pundit::NotAuthorizedError,
      with: :handle_not_authorized_error
  end

  private

  def handle_not_authorized_error
    redirect_to root_url,
      alert: "You are not authorized to perform this action."
  end
end
```

In a nested resource's `BaseController`, override `handle_not_authorized_error`. When the parent record is set and the user can see it, redirect to the parent instead. A user who can read a post but not comment on it goes back to the post, not to the root page. Otherwise call `super`, e.g. when the user can't see the post at all.

The `elsif` is optional. It redirects to the parent's index when the user can't see the parent but can see the list, e.g. a post that was unpublished. Keep `super` as the last case.

```ruby
module Posts
  class BaseController < ApplicationController
    # ...

    private

    def handle_not_authorized_error
      if @post && policy(@post).show?
        redirect_to @post,
          alert: "You are not authorized to perform this action."
      elsif policy(Post).index?
        redirect_to posts_url,
          alert: "You are not authorized to perform this action."
      else
        super
      end
    end
  end
end
```

## Strong parameters

Put the list of attributes a user can set in the policy, not the controller. Who can change what is an authorisation rule, so it belongs next to the other rules for the resource.

Define `permitted_attributes` in the policy and return each attribute in full. You MUST NOT return every column, e.g. `Post.column_names`. A new column then can't be set from a request until you add it to the list.

```ruby
class PostPolicy < ApplicationPolicy
  def permitted_attributes
    [:title, :body]
  end
end
```

In the controller, keep the private `post_params` method, but have it call Pundit's `permitted_attributes`. It reads the params under the singular name (`post`) and permits the policy's list. The actions read params the same way with or without Pundit.

Pass `@post`, so the policy checks the record being changed. Only write `@post || Post` when `@post` can be nil while `post_params` runs, e.g. `Post.new(post_params)` in `create`. Then the policy gets the class, because there's no record yet. If every action that calls `post_params` has already set `@post`, pass `@post` alone.

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
    permitted_attributes(@post || Post)
  end
end
```

### Different params per action

When `create` and `update` accept different attributes, replace `permitted_attributes` with one method per action: `permitted_attributes_for_create` and `permitted_attributes_for_update`. Pundit picks the method for the current action, so the controller keeps a single `post_params`. You MUST NOT keep a plain `permitted_attributes` next to them, or it isn't clear which one a new action uses.

Write out each list in full, even if some attributes repeat. You MUST NOT build one list from another. Then you can see exactly what each action accepts.

```ruby
class PostPolicy < ApplicationPolicy
  def permitted_attributes_for_create
    [:title, :body, :slug]
  end

  def permitted_attributes_for_update
    [:title, :body]
  end
end
```

### Access dependent params

Some attributes only some users can change, e.g. only an App Admin or a Publishing Manager can set `published`. Give each one its own permission method in the policy, named `update_<attribute>?`: `update_published?`. Then the rule has a name, and you can test it and reuse it on its own.

In `permitted_attributes`, start with the attributes every user can set. Then append each restricted attribute when its check is true. This doesn't break the rule about building lists, because the extra attributes come from checks in the same method, not from another list.

```ruby
class PostPolicy < ApplicationPolicy
  def update_published?
    user.app_admin? || user.publishing_manager?
  end

  def permitted_attributes
    attributes = [:title, :body]
    attributes << :published if update_published?
    attributes
  end
end
```

The same pattern works in `permitted_attributes_for_create` and `permitted_attributes_for_update`. Append the attribute in each method that accepts it.

### Other APIs

A policy has one set of `permitted_attributes`, so use them only for the main app. If the app has other APIs, e.g. a JSON API in `Api::V1`, each API accepts its own attributes. Give its controller a `post_params` method that uses `params.require` and `permit`, as in [Controllers: Strong parameters](../../controllers/#strong-parameters).

Reuse the policy's `update_<attribute>?` checks for access dependent params, so the access rule stays in one place.

```ruby
module Api
  module V1
    class PostsController < ApplicationController
      # PATCH /api/v1/posts/:id
      def update
        @post.update(post_params)
      end

      private

      def post_params
        attributes = [:title, :body]
        attributes << :published if policy(@post).update_published?
        params.require(:post).permit(attributes)
      end
    end
  end
end
```

## Views

You MUST NOT build a policy for a record in a view, e.g. `policy(@post).update?` or `policy(post).update?`. A view that loops over records builds a new policy for each check, and the checks end up spread across templates where nothing lists them.

Only call `policy` in a view with a class or a symbol. These checks don't depend on a record, e.g. `policy(Post).index?` for a link to the list, or `policy(:admin).index?` for a headless policy.

```erb
<% if policy(Post).new? %>
  <%= link_to "New post", new_post_path %>
<% end %>

<% if policy(:admin).index? %>
  <%= link_to "Admin", admin_root_path %>
<% end %>
```

When the app uses Draper, check a record's permissions through its decorator, e.g. `post.can_update?` or `post.can_publish?`. See [Draper: Permissions](../draper/#permissions).

## Forms

Forms check permissions too, e.g. to limit a collection to the choices the user can pick. Give them Pundit's `policy` and `policy_scope` through a `PunditPolicies` concern, in `app/forms/concerns/pundit_policies.rb`, and include it in `ApplicationForm`. See [Forms: Base class](../../forms/#base-class). The methods use the form's `current_user`, the same way the controller helpers do.

```ruby
module PunditPolicies
  extend ActiveSupport::Concern

  private

  def policy(class_or_resource)
    Pundit.policy!(current_user, class_or_resource)
  end

  def policy_scope(scope)
    Pundit.policy_scope!(current_user, scope)
  end
end
```

```ruby
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks
  include PunditPolicies

  # ...
end
```

```ruby
class UpdatePostForm < ApplicationForm
  # ...

  ### Collections ###

  def collection_for_status
    statuses = ["draft"]
    statuses << "published" if policy(post).update_published?
    statuses
  end
end
```

## Testing

See [Testing: Pundit](../../../testing/gems/pundit/).
