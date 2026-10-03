---
title: Draper
parent: Gems
grand_parent: The Guide
nav_order: 2
---

# Draper

Presentation logic with [Draper](https://github.com/drapergem/draper).

## When to use a decorator

Use a decorator method for presentation logic about one record, e.g. `post.published_on`, not a `post_published_on(post)` helper. Then the decorator spec covers each path, and you don't need a helper spec for it.

Keep helpers for general view elements that aren't about one record, e.g. `success_badge`, `date_tag` or `yes_no_tag`. The decorator builds its output with those helpers through `h`, e.g. `h.date_tag(object.published_at)`, so each element is marked up the same way everywhere. See [Views and Frontend: Helpers](../../views/#helpers).

Keep decorator methods simple: a formatted value, a link, or a small element built with a helper, e.g. `status_badge`. Never render a component or a partial from a decorator, e.g. `h.render(Posts::CardComponent.new(post: object))`. Render it in the view instead. The template then shows every part of the page it renders, and the decorator spec only checks simple values, not a whole component.

A decorator method only changes its output based on the record's state, e.g. `object.published?`, or on a record passed in its context. See [Context](#context). Never base it on the request, e.g. the current user, the params or a permission check. The method then returns the same value for the same records on every page, in a mailer or a broadcast, and its spec doesn't need a request. The `can_` permission checks are the one exception. See [Permissions](#permissions).

When a decorator method shows a value that isn't known, e.g. `published_at` is `nil`, prefer to return `h.unknown_value_tag` over `nil`, or your app's own alternative if it already shows missing values another way. See [Views and Frontend: Helpers](../../views/#helpers).

## Naming and layout

Name a decorator after its model, e.g. `PostDecorator` in `app/decorators/post_decorator.rb`. Inherit from `ApplicationDecorator`, so every decorator shares the same base, e.g. the permission checks in [Permissions](#permissions).

Lay out a decorator in groups, each under a `### Name ###` comment:

1. The model's own values first, without a heading: the `delegate` line, then the methods that format attributes.
2. `### Links ###`: every method that returns a link to the record.
3. Groups for your app's own elements, e.g. `### Badges ###`.
4. One group for each association, named after it, e.g. `### Comments ###`. Put the `decorates_association` and the delegates to it in the group.
5. `### Policy ###` last: the permission checks the view can make on the record. See [Permissions](#permissions).

Each method is then easy to find, and the groups read the same way in every decorator.

```ruby
class PostDecorator < ApplicationDecorator
  delegate :title

  def published_on
    if object.published_at
      h.date_tag(object.published_at)
    else
      h.unknown_value_tag
    end
  end

  ### Links ###

  def link
    h.link_to(object.title, h.post_path(object))
  end

  def edit_link
    h.link_to("Edit", h.edit_post_path(object))
  end

  ### Badges ###

  def status_badge
    h.success_badge("Published") if object.published?
  end

  ### Comments ###

  decorates_association :comments

  delegate :size, to: :comments, prefix: true

  ### Policy ###

  delegate :publish?, to: :policy, prefix: :can
end
```

## Decorating in controllers

Never decorate an instance variable in a controller. Assign the plain record to the instance variable, and use `decorates_assigned` to decorate it for the view.

The controller then works with the model the whole way through. Authorisation, saving and redirects all get the record, not a decorator that wraps it. `decorates_assigned` adds a helper method with the same name as the instance variable, which decorates the record the first time the view calls it.

```ruby
class PostsController < ApplicationController
  decorates_assigned :post

  # GET /posts/:id
  def show
    @post = Post.find(params[:id])
  end
end
```

The decorator adds the presentation methods the view needs:

```ruby
class PostDecorator < ApplicationDecorator
  delegate :title

  def published_on
    if object.published_at
      h.date_tag(object.published_at)
    else
      h.unknown_value_tag
    end
  end
end
```

Avoid `delegate_all`, unless you're working in legacy code that already relies on it. Delegate each model method the view reads by name, e.g. `delegate :title`, and read the model through `object` inside the decorator. The decorator then lists every value the view can read, and its specs can cover each one. With `delegate_all`, the view can read any value from the model through the decorator, and nothing shows which ones it uses.

Only delegate a model method when the view shows its value as it is, e.g. `title`. When a value needs consistent formatting, e.g. a date or a status, write a decorator method for it, e.g. `published_on`, and don't delegate the raw attribute.

The view calls the helper method instead of the instance variable:

```erb
<h1><%= post.title %></h1>
<p><%= post.published_on %></p>
```

`decorates_assigned` infers the decorator from the record, e.g. `PostDecorator` for a `Post`. If a view needs a different decorator, pass it with the `with:` argument.

```ruby
class PostsController < ApplicationController
  decorates_assigned :post, with: Posts::SummaryDecorator
end
```

Never call `decorate` in a view or a helper, e.g. `@post.decorate` in a template or `PostDecorator.new(post)` in a helper. Add a `decorates_assigned` to the controller instead. The view and its helpers then always get records that are already decorated, and the controller shows in one place which decorator each view uses.

Only use Draper for HTML responses. An API endpoint that returns another format, e.g. JSON in `Api::V1`, doesn't use `decorates_assigned` or decorators. Decorator methods return markup for a page, e.g. `h.date_tag`, which an API client can't use.

### Context

Sometimes a decorator needs a record it can't reach from its own record. E.g. at `GET /tags/:tag_id/posts`, a post belongs to many tags, so the post can't tell which tag the page is for. Pass that record in with the `context:` option. In the decorator, read it through a private method named after it, e.g. `tag`, with `context.fetch(:tag)`. `fetch` raises a `KeyError` when a controller forgets to pass the tag, instead of building a broken link from `nil`.

Decorate the parent with its own `decorates_assigned`, usually in the nested resource's `BaseController`, e.g. `Tags::BaseController`. `decorates_assigned` calls a `context:` lambda with the controller, so the lambda can pass the decorated parent with `c.tag`. For a collection, Draper passes the context on to each record's decorator.

```ruby
module Tags
  class PostsController < ApplicationController
    decorates_assigned :tag
    decorates_assigned :posts, context: ->(c) { { tag: c.tag } }

    # GET /tags/:tag_id/posts
    def index
      @tag = Tag.find(params[:tag_id])
      @posts = @tag.posts
    end
  end
end
```

```ruby
class PostDecorator < ApplicationDecorator
  ### Links ###

  def tag_post_link
    h.link_to(object.title, h.tag_post_path(tag, object))
  end

  private

  def tag
    context.fetch(:tag)
  end
end
```

Only pass records in the context, never the current user, the params or other request state.

## Associations

Decorate a required association in the decorator with `decorates_association`. The associated record then comes back with its own decorator, so its presentation logic stays in one place.

Don't let the view reach through the association, e.g. `comment.post.published_on`. Delegate the methods the view needs to the decorated association with a prefix, e.g. `comment.post_published_on`. The view then only talks to the record it was given, which keeps the [Law of Demeter](https://en.wikipedia.org/wiki/Law_of_Demeter). The delegated methods are the associated decorator's methods, so the value is formatted the same way on every page.

```ruby
class CommentDecorator < ApplicationDecorator
  decorates_association :post

  delegate :title, :published_on, to: :post, prefix: true
end
```

```erb
<p>On <%= comment.post_title %>, published <%= comment.post_published_on %></p>
```

An optional association can be `nil`, and then a delegate to it raises an error. For an optional association, write the association method yourself instead of using `decorates_association`. Decorate the record when there is one, and fall back to a `NilDecorator` when there isn't. Memoise the result, so every delegate to the association reuses the same decorator, the way `decorates_association` does.

```ruby
class PostDecorator < ApplicationDecorator
  ### Author ###

  def author
    @author ||= object.author&.decorate || NilDecorator.for(User)
  end

  delegate :name, to: :author, prefix: true
end
```

`NilDecorator.for(klass)` builds a stand-in for the decorator of `klass`. It answers every method that the real decorator has with `unknown_value_tag`, so `post.author_name` shows a missing value the same way as any other. It returns `false` for every permission check, e.g. `post.author.can_update?`, because `unknown_value_tag` is truthy and would pass the check. See [Permissions](#permissions). It raises `NoMethodError` for a method the real decorator doesn't have, so a typo still fails. It is never `present?`, so the view can still check `post.author.present?` before it shows a whole section.

This is where the prefixed delegates pay off. The view only calls `post.author_name`, so it doesn't need to know whether there is an author. If the view reached through, e.g. `post.author.name`, every call would need its own `nil` check, and a missing author would break each page that forgot one.

```ruby
# app/decorators/nil_decorator.rb
class NilDecorator
  include Draper::ViewHelpers

  def self.for(klass)
    new(klass.new.decorate)
  end

  def initialize(decorator)
    @decorator = decorator
  end

  def present?
    false
  end

  def blank?
    true
  end

  def presence
    nil
  end

  def method_missing(name, *args, &block)
    if !@decorator.respond_to?(name)
      super
    elsif name.start_with?("can_") && name.end_with?("?")
      false
    else
      h.unknown_value_tag
    end
  end

  def respond_to_missing?(name, include_private = false)
    @decorator.respond_to?(name, include_private) || super
  end
end
```

For a `has_many` association, only add `decorates_association` when a view uses the whole association, e.g. `decorates_association :comments`.

When a view needs a scoped part of an association, add a scoped association to the model, e.g. `approved_comments`, and decorate it with `decorates_association`. Don't build the scope in the decorator. The model then owns which comments count as approved, the controller can preload them, and the decorator only presents them. Put both in the association's group.

```ruby
class Post < ApplicationRecord
  has_many :comments
  has_many :approved_comments, -> { approved }, class_name: "Comment"
end
```

```ruby
class PostDecorator < ApplicationDecorator
  ### Comments ###

  decorates_association :comments
  decorates_association :approved_comments
end
```

## Collections

Decorate a collection with `decorates_assigned` too, the same way as one record. Assign the plain relation to the instance variable. Draper wraps it in a `Draper::CollectionDecorator`, which decorates each record with its own decorator, e.g. `PostDecorator` for each `Post`.

```ruby
class PostsController < ApplicationController
  decorates_assigned :posts

  # GET /posts
  def index
    @posts = Post.all
  end
end
```

Handle an empty collection in the view. The collection decorator answers `empty?`, so the view can check it before it renders the list.

```erb
<% if posts.empty? %>
  <p>No posts yet.</p>
<% else %>
  <%= render posts %>
<% end %>
```

Only write a collection decorator when the view needs a summary value from the whole collection, e.g. `last_comment_at`, or the list is paginated (see below). Name it after the plural of the model, e.g. `CommentsDecorator` in `app/decorators/comments_decorator.rb`, and pass it to `decorates_assigned` with `with:`. Otherwise the default `Draper::CollectionDecorator` is enough.

```ruby
class CommentsDecorator < Draper::CollectionDecorator
  def last_comment_at
    if (created_at = object.maximum(:created_at))
      h.date_tag(created_at)
    else
      h.unknown_value_tag
    end
  end
end
```

```ruby
class Posts::CommentsController < ApplicationController
  decorates_assigned :comments, with: CommentsDecorator

  # GET /posts/:post_id/comments
  def index
    @comments = Post.find(params[:post_id]).comments
  end
end
```

The default collection decorator does not delegate the methods your paginator needs, e.g. `current_page` and `total_pages`. Write one concern for each paginator that delegates those methods to the collection, and name it after the paginator, e.g. `KaminariPagination` in `app/decorators/concerns/kaminari_pagination.rb`. Include it in the collection decorator for each paginated list.

```ruby
# app/decorators/concerns/kaminari_pagination.rb
module KaminariPagination
  extend ActiveSupport::Concern

  included do
    delegate :current_page, :total_pages, :limit_value, :total_count, :offset_value, :last_page?
  end
end
```

```ruby
class PostsDecorator < Draper::CollectionDecorator
  include KaminariPagination
end
```

```ruby
class PostsController < ApplicationController
  decorates_assigned :posts, with: PostsDecorator

  # GET /posts
  def index
    @posts = Post.page(params[:page])
  end
end
```

```erb
<%= render posts %>
<%= paginate posts %>
```

## Permissions

With [Pundit](../pundit/), check a record's permissions through its decorator, not with `policy(post)` in the view. See [Pundit: Views](../pundit/#views).

Build the policy in `ApplicationDecorator` from the view's `policy` helper, e.g. `h.policy(object)`. Pass `object`, so Pundit finds the policy for the model, e.g. `PostPolicy`. Memoise it, so each record builds its policy once, however many checks the view makes. Keep the `policy` method private, so the view can't reach through it, e.g. `post.policy.update?`.

In the same `### Policy ###` group, delegate the checks for the standard Rails actions to the policy with a `can` prefix: `can_index?`, `can_show?`, `can_new?`, `can_create?`, `can_edit?`, `can_update?` and `can_destroy?`. Every decorator then answers them. The prefix shows that the method is a permission check, and it keeps the check apart from the model's own methods, e.g. `post.update` or `post.new_record?`.

```ruby
class ApplicationDecorator < Draper::Decorator
  ### Policy ###

  delegate :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :policy, prefix: :can

  private

  def policy
    @policy ||= h.policy(object)
  end
end
```

For a custom action, delegate its check in the model's own decorator, with the same `can` prefix, e.g. `can_publish?` for `PostPolicy#publish?`. Put it in the decorator's `### Policy ###` group.

```ruby
class PostDecorator < ApplicationDecorator
  ### Policy ###

  delegate :publish?, to: :policy, prefix: :can
end
```

A user can have permission for an action that would still fail right now. Then the view shouldn't offer it. For example, a post `has_many :comments, dependent: :restrict_with_error`, so destroying a post with comments fails with a 422, even for a user who may delete it. Override the `can_` check in the model's decorator to add the view's own condition. Call `super` first, so the policy check always runs.

```ruby
class PostDecorator < ApplicationDecorator
  ### Policy ###

  def can_destroy?
    super && object.comments.none?
  end
end
```

Only add business rules, e.g. a post with comments can't be deleted. Don't add rules about who may do it. Those belong in the policy, where the controller's `authorize` checks them too. For a custom action, define the `can_` method in place of its `delegate`, and call the policy first, e.g. `policy.publish? && ...`.

Never make another decorator method depend on a permission, e.g. `edit_link` that returns `nil` unless `can_update?`. The view decides. When the view shows something else to a user who can't follow a link, e.g. a disabled link, add a method for it next to the link, e.g. `disabled_link`, and let the view choose between them.

```ruby
class PostDecorator < ApplicationDecorator
  ### Links ###

  def link
    h.link_to(object.title, h.post_path(object))
  end

  def disabled_link
    h.tag.span(object.title, aria: { disabled: true })
  end
end
```

The view asks the record it was given:

```erb
<% if post.can_show? %>
  <%= post.link %>
<% else %>
  <%= post.disabled_link %>
<% end %>

<% if post.can_update? %>
  <%= post.edit_link %>
<% end %>

<% if post.can_publish? %>
  <%= button_to "Publish", publish_post_path(post) %>
<% end %>
```

## Testing

Write a decorator spec in `spec/decorators` for each decorator. Give each method its own `describe` block, and write an example for each path through it. A method with an `if` needs one example for each side.

Build the record being decorated with an `instance_double`, and stub only the values the method reads. The spec then runs without the database, and it fails if the decorator reads a method the model doesn't have. Use a factory only when an `instance_double` can't stand in for the record.

```ruby
RSpec.describe PostDecorator do
  subject(:decorator) { described_class.new(post) }

  describe "#published_on" do
    context "when the post is published" do
      let(:post) { instance_double(Post, published_at: Time.zone.local(2026, 10, 3, 9, 30)) }

      it "returns the date it was published" do
        expect(decorator.published_on).to eq('<time datetime="2026-10-03">October 03, 2026</time>')
      end
    end

    context "when the post is a draft" do
      let(:post) { instance_double(Post, published_at: nil) }

      it "returns the unknown value tag" do
        expect(decorator.published_on).to eq(helpers.unknown_value_tag)
      end
    end
  end
end
```

A decorator spec covers the presentation logic for a record, so you don't need a helper spec for it. See [When to use a decorator](#when-to-use-a-decorator).

### Context

To spec a method that reads its context, e.g. `tag_post_link`, add a `context` block for it. In the block, define the record with `let`, decorated the same way the controller passes it, e.g. a `TagDecorator`. Then override the subject to pass it in the decorator's context. Only the examples that need the context build it, and each one shows which record it gets.

```ruby
RSpec.describe PostDecorator do
  subject(:decorator) { described_class.new(post) }

  describe "#tag_post_link" do
    context "with a tag" do
      subject(:decorator) { described_class.new(post, context: { tag: tag }) }

      let(:post) { instance_double(Post, title: "Hello", to_param: "1") }
      let(:tag) { TagDecorator.new(instance_double(Tag, to_param: "2")) }

      it "links to the post under the tag" do
        expect(decorator.tag_post_link).to eq('<a href="/tags/2/posts/1">Hello</a>')
      end
    end
  end
end
```

### Permissions

Spec each `can_` method that you override, e.g. `can_destroy?`, with an example for each path: the policy forbids it, the business rule forbids it, and both allow it. Don't spec the plain delegates. The policy spec covers who may do what.

Stub the policy, so the spec doesn't need a signed-in user. Build it with an `instance_double` of the policy class, and stub `helpers.policy` to return it. `helpers` is the same view context the decorator reads through `h`. Stub it in each context, not at the top of the spec, so each example shows the permission it runs with, and specs for other methods don't build a policy.

```ruby
RSpec.describe PostDecorator do
  subject(:decorator) { described_class.new(post) }

  describe "#can_destroy?" do
    context "when the post has no comments" do
      let(:post) { instance_double(Post, comments: []) }

      before do
        allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: true))
      end

      it { expect(decorator.can_destroy?).to be(true) }
    end

    context "when the post has comments" do
      let(:post) { instance_double(Post, comments: [instance_double(Comment)]) }

      before do
        allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: true))
      end

      it { expect(decorator.can_destroy?).to be(false) }
    end

    context "when the policy forbids it" do
      let(:post) { instance_double(Post, comments: []) }

      before do
        allow(helpers).to receive(:policy).with(post).and_return(instance_double(PostPolicy, destroy?: false))
      end

      it { expect(decorator.can_destroy?).to be(false) }
    end
  end
end
```
