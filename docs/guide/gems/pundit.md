---
title: Pundit
parent: Gems
grand_parent: The Guide
nav_order: 3
---

# Pundit

Authorisation with [Pundit](https://github.com/varvet/pundit).

## Setup

Put Pundit's setup in a `PunditAuthorization` concern, in `app/controllers/concerns/pundit_authorization.rb`, and include it in `ApplicationController`. All of the setup is then in one file. See [Directory Layout: Concerns](../../directory-layout/#gem-setup).

The concern includes Pundit and adds its `verify_authorized` check, so every controller requires it by default. It raises an error when an action finishes without calling `authorize`, so a missing check fails in your specs rather than leaving the action open. See [Controllers](#controllers) below for how each action calls `authorize` or opts out.

Leave out Devise's own controllers, because you can't add checks to their actions.

```ruby
module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    after_action :verify_authorized, unless: :devise_controller?
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

> **TODO:** Describe how you handle this.

## Scopes

> **TODO:** Describe how you handle this.

## Controllers

Call `authorize` on the first line of every action, as in [Controllers: Authorization](../../controllers/#authorization). Pass the record when the action has one, and the class when it doesn't, e.g. in `index`, `new` and `create`.

```ruby
class PostsController < ApplicationController
  # GET /posts
  def index
    authorize Post
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

If an action really needs no check, call `skip_authorization` on its first line. Don't use `skip_after_action :verify_authorized` at the top of the controller, because it also covers any action added later.

```ruby
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :about

  # GET /about
  def about
    skip_authorization
  end
end
```

### Nested resources

A nested resource's `BaseController` checks that the user can see the parent record. See [Controllers: Nested resources](../../controllers/#nested-resources). Don't use `authorize` for this check. It marks the request as authorised, so `verify_authorized` would pass for every nested action, and an action with no check of its own would be left open.

Use `pundit.authorize` instead, with the `query:` and `policy_class:` keywords. It raises an error like `authorize` does when the user can't see the post, but it doesn't mark the request as authorised. Each nested action must still call `authorize` itself, or `verify_authorized` fails. `pundit.authorize` needs Pundit 2.4 or later.

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

      @comments = @post.comments
    end

    # POST /posts/:post_id/comments
    def create
      authorize Comment
    end
  end
end
```

## Strong parameters

Put the list of attributes a user may set in the policy, not the controller. Who can change what is an authorisation rule, so it belongs next to the other rules for the resource.

Define `permitted_attributes` in the policy and return each attribute in full. Never return every column, e.g. `Post.column_names`. A new column then can't be set from a request until you add it to the list.

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

When `create` and `update` accept different attributes, replace `permitted_attributes` with one method per action: `permitted_attributes_for_create` and `permitted_attributes_for_update`. Pundit picks the method for the current action, so the controller keeps a single `post_params`. Don't keep a plain `permitted_attributes` next to them, or it isn't clear which one a new action should use.

Write out each list in full, even if some attributes repeat. Don't build one list from another. Then you can see exactly what each action accepts.

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

Some attributes only some users may change, e.g. only an App Admin or a Publishing Manager may set `published`. Give each one its own permission method in the policy, named `update_<attribute>?`: `update_published?`. Then the rule has a name, and you can test it and reuse it on its own.

In `permitted_attributes`, start with the attributes every user may set. Then append each restricted attribute when its check is true. This doesn't break the rule about building lists, because the extra attributes come from checks in the same method, not from another list.

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

The same pattern works in `permitted_attributes_for_create` and `permitted_attributes_for_update`. Append the attribute in each method that should accept it.

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

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
