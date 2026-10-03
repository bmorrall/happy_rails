---
applyTo: "app/policies/**/*.rb,app/controllers/**/*.rb,app/views/**,spec/policies/**/*.rb"
---

# Pundit

- Put Pundit's setup in a `PunditAuthorization` concern in `app/controllers/concerns/pundit_authorization.rb`, with `include Pundit::Authorization` and `after_action :verify_authorized, unless: :devise_controller?` in its `included` block. Add `include PunditAuthorization` to `ApplicationController`. Never add `verify_authorized` to individual controllers.
- Call `authorize` on the first line of every action. Pass the record when the action has one, and the class when it does not, e.g. `authorize @post` in `show` and `update`, and `authorize Post` in `index`, `new` and `create`.
- When an action needs no authorisation check, call `skip_authorization` on its first line, e.g. `def about; skip_authorization; end` in `PagesController`. Never use `skip_after_action :verify_authorized`.
- In a nested resource's `BaseController`, check the parent with `pundit.authorize`, which does not mark the request as authorised, e.g. `pundit.authorize(@post, query: :show?, policy_class: PostPolicy)` in `Posts::BaseController#set_post`. Never use plain `authorize` there, because it makes `verify_authorized` pass for every nested action. Each nested action still calls `authorize` itself, e.g. `authorize Comment` in `Posts::CommentsController#index`. `pundit.authorize` needs Pundit 2.4 or later.
- Rescue failed checks in the `PunditAuthorization` concern with `rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized`. In the private `handle_not_authorized` method, redirect to the root page with an alert, e.g. `redirect_to root_url, alert: "You are not authorized to perform this action."`.
- In a nested resource's `BaseController`, override `handle_not_authorized`. Redirect to the parent record when it is set and the user can see it, and call `super` otherwise, e.g. `if @post && policy(@post).show?` then `redirect_to @post, alert: "You are not authorized to perform this action."`, else `super`, in `Posts::BaseController`.
- Optionally, when the user cannot see the parent record but can see its index, redirect to the index before falling back to `super`, e.g. `elsif policy(Post).index?` then `redirect_to posts_url, alert: "You are not authorized to perform this action."` in `Posts::BaseController#handle_not_authorized`.
- Put permitted attributes in the policy, not the controller. Define `permitted_attributes` and return an explicit list, e.g. `PostPolicy#permitted_attributes` returns `[:title, :body]`. Never return every column, e.g. `Post.column_names`.
- In controllers, keep a private params method named after the resource that calls Pundit, e.g. `post_params` returns `permitted_attributes(@post)`. Actions use it as usual, e.g. `@post.update(post_params)`.
- Only fall back to the class when `@post` can be nil while `post_params` runs, e.g. `permitted_attributes(@post || Post)` when `create` calls `Post.new(post_params)`. If every action that calls `post_params` has already set `@post`, pass `@post` alone.
- When actions accept different attributes, replace `permitted_attributes` with one method per action, e.g. `permitted_attributes_for_create` and `permitted_attributes_for_update`. Do not keep a plain `permitted_attributes` next to them. Keep a single `post_params` in the controller, because Pundit picks the method for the current action.
- Write each action's list in full, even if attributes repeat, e.g. `permitted_attributes_for_create` returns `[:title, :body, :slug]` and `permitted_attributes_for_update` returns `[:title, :body]`. Do not build one list from another.
- When only some users may change an attribute, add a permission method named `update_<attribute>?` to the policy, e.g. `PostPolicy#update_published?` returns `user.app_admin? || user.publishing_manager?`. In the permitted attributes method, start with the attributes every user may set, then append the restricted attribute when its check is true, e.g. `attributes << :published if update_published?`.
- Use the policy's permitted attributes only for the main app. In controllers for other APIs, e.g. `Api::V1::PostsController`, define `post_params` with `params.require` and `permit` instead. Reuse the policy's `update_<attribute>?` checks for restricted attributes, e.g. `attributes << :published if policy(@post).update_published?`.
- Never build a policy for a record in a view, e.g. `policy(@post).update?` or `policy(post).update?` in `app/views/posts/index.html.erb`. Only call `policy` in a view with a class or a symbol, e.g. `policy(Post).new?` or `policy(:admin).index?`.
- When the app uses Draper, check a record's permissions in a view through its decorator, e.g. `post.can_update?` or `post.can_publish?`.
- TODO: How to write a policy, e.g. `PostPolicy`.
- TODO: How to write a policy scope and call `policy_scope` in controllers.
- TODO: How to write policy specs.
