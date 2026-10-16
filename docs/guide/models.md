---
title: Models
parent: The Guide
nav_order: 3
---

# Models

How models are written and organised.

## Layout

Group the declarations in a model under comment headings, e.g. `### Attributes ###`, in this order:

1. Scopes
2. Constants
3. Attributes
4. Enumerations
5. Associations
6. Validations
7. Callbacks
8. Modules, with the name of the gem in brackets, e.g. `### Modules (FriendlyId) ###`
9. Public Methods

Every model then reads the same way, so you know where to look for a declaration and where to add a new one. Leave out a group if the model has nothing in it.

If a model uses more than one gem, give each gem its own Modules heading. Order them alphabetically, unless one gem depends on another being set up first.

Put an `include` or `extend` at the top of the model only when a later declaration needs it. For example, a later line might call a macro the module defines, or the module's callbacks might have to run before the model's own. It does not need a heading there. Add a comment saying what needs it instead. Without the comment, the next person might move it back down and break the model.

```ruby
class Post < ApplicationRecord
  # Sluggable must come before slug_from
  include Sluggable

  ### Attributes ###

  slug_from :title

  # ...
end
```

Put shared logic in `concerning` blocks. If the block supports a gem's module, put it under that module's heading. Put any other `concerning` block under Public Methods. The `UserAccess` block MAY go at the top of the model instead. See [User access](#user-access). Private methods go last, after `private`. Order them by the group they support, in the same order as the headings. For example, a validation method comes before a callback method.

```ruby
class Post < ApplicationRecord
  ### Scopes ###

  scope :recent,
    -> { order(created_at: :desc) }

  ### Constants ###

  TITLE_MAX_LENGTH = 100

  ### Attributes ###

  attribute :featured, :boolean,
    default: false

  ### Enumerations ###

  enum :status, { draft: "draft", published: "published" }

  ### Associations ###

  belongs_to :author,
    class_name: "User"

  has_many :comments,
    dependent: :destroy

  ### Validations ###

  validates :title,
    presence: true,
    length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }

  validate :published_at_cannot_be_in_the_future

  ### Callbacks ###

  before_save :set_published_at,
    if: :published?

  ### Modules (FriendlyId) ###

  extend FriendlyId
  friendly_id :title, use: :slugged

  concerning :Slugs do
    def should_generate_new_friendly_id?
      title_changed?
    end
  end

  ### Public Methods ###

  concerning :Publishing do
    def recently_published?
      published? && published_at >= 1.week.ago
    end
  end

  private

  def published_at_cannot_be_in_the_future
    return if published_at.blank? || published_at <= Time.zone.now

    errors.add(:published_at, "can't be in the future")
  end

  def set_published_at
    self.published_at ||= Time.zone.now
  end
end
```

## Validations

When an attribute has `presence: true`, add `allow_blank: true` to its other validators. A blank value then gets one error, "can't be blank", not a stack of errors that all say it's missing. See [Validators: Blank values](../validators/#blank-values).

```ruby
validates :title,
  presence: true,
  length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }
```

### Normalising values

Tidy a value with `normalizes`, e.g. to strip spaces or remove hyphens. Put it under `### Attributes ###`. Rails runs it whenever the attribute is set, so validations always see the tidy value. It also runs on the values you pass to finders, e.g. `Post.find_by(isbn: "978-0306406157")` finds a post saved with `9780306406157`. Rails skips `nil`, so the block doesn't need `&.`.

```ruby
class Post < ApplicationRecord
  ### Attributes ###

  normalizes :title,
    with: ->(title) { title.strip }

  normalizes :isbn,
    with: ->(isbn) { isbn.delete("-") }

  # ...
end
```

You MUST NOT tidy a value in a `before_validation` callback, or by overriding its writer. A callback leaves the value untidy until the record is validated, and finders never use either of them. `normalizes` needs Rails 7.1 or later. Before that, tidy the value in a `before_validation` callback under `### Callbacks ###`, e.g. `before_validation { self.title = title&.strip }`.

### State validations

When a value is required in one state, validate it on the state, e.g. `validates :rejection_reason, presence: true, if: :rejected?`. Every save checks it, however the record reached the state, and a later edit can't clear it.

You SHOULD NOT validate it in a custom validation context, e.g. `on: :reject`. A custom context only runs when the code passes it, e.g. `save!(context: :reject)`, so any other way into the state skips the rule. Rails' own `on: :create` and `on: :update` are fine, because Rails passes them on every save.

```ruby
class Post < ApplicationRecord
  # ...

  ### Validations ###

  validates :rejection_reason,
    presence: true,
    if: :rejected?
end
```

Check the state being entered with its predicate, e.g. `rejected?`. When a record changes state, e.g. with `post.update!(status: :rejected)`, the new state is set before the save, so the predicate is already true when validations run. Use `status_in_database` only to check the state being left, e.g. `if: -> { status_in_database == "published" }`.

A value that only belongs to one state SHOULD be blank in every other state. Validate its absence outside the state, and clear it in the code that moves the record out of the state. A stale value can't then linger, e.g. an old rejection reason on a post that went back to draft.

```ruby
validates :rejection_reason,
  absence: true,
  unless: :rejected?
```

A state with several validations MAY group them in `with_options`, so the condition is written once.

```ruby
with_options if: :rejected? do
  validates :rejection_reason,
    presence: true

  validates :rejected_by,
    presence: true
end
```

When a validation applies to several states, name a predicate after what those states have in common, e.g. `has_been_approved?` for `approved? || published?`. You SHOULD NOT name it after the states, e.g. `approved_or_published?`. The name then says why the value is required, and stays true when a new state joins the list.

```ruby
class Post < ApplicationRecord
  # ...

  ### Validations ###

  validates :approved_by,
    presence: true,
    if: :has_been_approved?

  # ...

  ### Public Methods ###

  def has_been_approved?
    approved? || published?
  end
end
```

When a value can't change once a record is in a state, lock it with a validation on the state and the change. You SHOULD NOT reset it in a callback. The validation shows the mistake, and a callback hides it. See [Callbacks](#callbacks).

```ruby
class Post < ApplicationRecord
  # ...

  ### Validations ###

  validate :slug_unchanged,
    if: -> { published? && will_save_change_to_slug? }

  # ...

  private

  def slug_unchanged
    errors.add(:slug, "can't change once the post is published")
  end
end
```

### Validations that run on change

An expensive validation, e.g. one that runs a query, SHOULD run only on a save that changes a value it reads. A record that saves often then doesn't repeat the work when nothing it checks has changed. When the validation also reads the state, run it when the state changes too, so the record can't enter the state without the check.

```ruby
validates :slug,
  uniqueness: true,
  if: -> { will_save_change_to_slug? || will_save_change_to_status? }
```

Leave cheap validations to run on every save, e.g. `presence` or `length`. They cost almost nothing, and they still catch a value that was changed without a validation, e.g. with `update_column`. A skipped check can't see changes to other records either, e.g. a duplicate slug saved since. Back a rule like that with a database constraint, e.g. a unique index, as in [Database constraints](#database-constraints).

A validation that compares a value with the current time SHOULD run only on the save that changes the value, e.g. `if: :will_save_change_to_publish_at?`. Otherwise it fails every later save once the time has passed, e.g. a typo fix on a scheduled post.

```ruby
validates :publish_at,
  comparison: { greater_than: -> { Time.zone.now } },
  allow_nil: true,
  if: :will_save_change_to_publish_at?
```

### Database constraints

You MAY back a business rule that must never break with a database constraint, as well as the validation, e.g. a check constraint. A validation misses writes that skip it, e.g. `update_column`, `update_all` or SQL. The validation still gives the user a clear error, and the constraint catches everything else.

```ruby
class AddRejectionReasonToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :rejection_reason, :text

    add_check_constraint :posts,
      "status <> 'rejected' OR (rejection_reason IS NOT NULL AND rejection_reason <> '')",
      name: "posts_rejection_reason_required"
  end
end
```

String enum values keep the constraint readable, e.g. `status <> 'rejected'`. See [Enums](#enums). A constraint MAY also check that a value is blank outside its state, e.g. `(status = 'rejected') = (rejection_reason IS NOT NULL)`.

> **TODO:** Describe how you handle the rest of this.

## Associations

Always pass `dependent:` to `has_many`. Rails leaves the associated records in place by default, and a missing option looks the same as a forgotten one. With the option on every `has_many`, each one shows a choice, and a reviewer can check what happens to the records when their parent is deleted.

Start with `dependent: :restrict_with_exception`. Deleting a record that still has associated records then raises an error, so nothing is deleted or left behind by accident. Change it once you've decided what happens to them, e.g. `:destroy` when a post's comments go with it. Write `dependent: nil` only when the records stay, e.g. for a scoped association whose records another association already handles.

```ruby
class Post < ApplicationRecord
  ### Associations ###

  has_many :comments,
    dependent: :destroy

  has_many :approved_comments,
    -> { approved },
    class_name: "Comment",
    dependent: nil

  has_many :publications,
    dependent: :restrict_with_exception
end
```

`approved_comments` uses `dependent: nil` because `comments` already deletes the same records. A published post can't be deleted until you decide what happens to its publications.

> **TODO:** Describe how you handle the rest of this.

## Scopes and queries

When code outside the model builds a query on a record's association in more than one step, e.g. `post.comments.where(locked: false)`, give the model a method that returns it, e.g. `Post#unlocked_comments`. The caller then talks to the post, not to the post's comments and the `where` behind them. The method only reads. The caller still does any writes, e.g. `post.unlocked_comments.update_all(locked: true, updated_at: Time.zone.now)` in an action.

When only one task uses the method, put it in a `concerning` block named after that task, e.g. `concerning :Archiving`. The block shows which task the method is for. When another task needs it too, move it out of the block, under Public Methods.

```ruby
class Post < ApplicationRecord
  # ...

  ### Public Methods ###

  concerning :Archiving do
    def unlocked_comments
      comments.where(locked: false)
    end
  end
end
```

The method can use a scope on the associated model, e.g. `scope :unlocked, -> { where(locked: false) }` on `Comment`, so `Post#unlocked_comments` returns `comments.unlocked`. The caller still calls the method, e.g. `post.unlocked_comments`, not `post.comments.unlocked`. A spec for the caller then stubs one method on the post, not a chain.

```ruby
class Comment < ApplicationRecord
  ### Scopes ###

  scope :unlocked, -> { where(locked: false) }

  # ...
end
```

```ruby
class Post < ApplicationRecord
  # ...

  concerning :Archiving do
    def unlocked_comments
      comments.unlocked
    end
  end
end
```

The same goes for a query that starts from a class, e.g. the comments on a relation of posts. Give the class a method that builds it, e.g. `Comment.on_posts(posts)`, not `Comment.where(post: posts)` in the caller. A spec for the caller can then stub the class method, e.g. `allow(Comment).to receive(:on_posts).with(posts)`.

```ruby
class Comment < ApplicationRecord
  # ...

  concerning :Archiving do
    class_methods do
      def on_posts(posts)
        where(post: posts)
      end
    end
  end
end
```

You MUST NOT build the chain in the action.

```ruby
# Don't do this
post.comments.where(locked: false).update_all(locked: true, updated_at: Time.zone.now)
Comment.where(post: posts).update_all(locked: true, updated_at: Time.zone.now)
```

> **TODO:** Describe how you handle the rest of this.

## User access

Give each role a user can hold on one record two methods, in a `concerning :UserAccess` block:

- `user_is_<role>?(user)` checks the role on one record, e.g. `post.user_is_author?(user)`.
- `for_user_as_<role>(user)`, a scope, lists the records the user holds the role on, e.g. `Post.for_user_as_author(user)`. Define it with `scope` in the block's `included` block.

Then each role is written once. A policy's permissions and scope call these methods, and so does a form that only offers the records a user holds a role on, e.g. the posts they wrote. See [Pundit: Roles on the record](../gems/pundit/#roles-on-the-record).

Keep a role on the whole app on `User` when it covers every record, e.g. `user.app_admin?`. When it only covers some records, give it `UserAccess` methods too, and put the condition in them. For example, a Copy Editor can only edit draft posts, so `user_is_copy_editor?` checks that the post is a draft, and `for_user_as_copy_editor` lists drafts for a Copy Editor and none for anyone else.

Put the `UserAccess` block under Public Methods, like any other `concerning` block. It MAY go at the top of the model instead, above every heading. Who can do what with a record is often the most important thing to know about it, so it's the first thing you read.

```ruby
class Post < ApplicationRecord
  concerning :UserAccess do
    included do
      scope :for_user_as_copy_editor,
        ->(user) { user.copy_editor? ? draft : none }
      scope :for_user_as_author,
        ->(user) { where(author_id: user.id) }
      scope :for_user_as_coauthor,
        ->(user) { where(id: user.coauthored_posts) }
    end

    def user_is_copy_editor?(user)
      draft? && user.copy_editor?
    end

    def user_is_author?(user)
      author_id == user.id
    end

    def user_is_coauthor?(user)
      coauthorships.any? { |coauthorship| coauthorship.user_id == user.id }
    end
  end

  ### Scopes ###

  # ...
end
```

A view checks a permission for every post in a list, so `user_is_<role>?` runs once for each post. Write it so it doesn't run a query for each post.

When the role comes from a `belongs_to`, e.g. the Author, compare the foreign key: `author_id == user.id`. Both values are already loaded, so the check runs no query. You SHOULD NOT compare the records, e.g. `author == user`. It loads the author of each post.

When the role comes from a join, e.g. a Co-author, read the record's join rows with `any?` and a block: `coauthorships.any? { |coauthorship| coauthorship.user_id == user.id }`. A list preloads them, e.g. `policy_scope(Post).includes(:coauthorships)`. The policy scope has already limited the list to the posts the user can see, so the preload only loads the rows for those posts. A tool like Bullet flags a list that forgot the `includes`.

You SHOULD NOT call `include?` or `exists?` on an association, e.g. `coauthors.include?(user)` or `user.coauthored_posts.include?(self)`. When the association isn't loaded, each call runs its own query, so a list runs one for each post, and preloading can't prevent it.

```ruby
# Don't do this
class Post < ApplicationRecord
  concerning :UserAccess do
    def user_is_author?(user)
      author == user
    end

    def user_is_coauthor?(user)
      coauthors.include?(user)
    end
  end
end
```

## Callbacks

A callback only changes the record's own attributes, e.g. setting `published_at` before a published post is saved. You MUST NOT use a callback to create, change or delete another record, enqueue a job, send an email or call another service. This includes `after_commit` callbacks.

A callback runs on every save, wherever it comes from: a form, a job, the console, a seed file or a factory in a spec. Work in a callback that reaches outside the record runs in all of those places, even when the caller didn't want it. You also can't see it in the code that saves the record. Put that work in the form, action or job that does the task instead. The caller then shows everything that happens. See [Side Effects of Saving](../../patterns/side-effects-of-saving/) for where each kind of work goes.

```ruby
class Post < ApplicationRecord
  ### Callbacks ###

  before_save :set_published_at,
    if: :published?

  # ...

  private

  def set_published_at
    self.published_at ||= Time.zone.now
  end
end
```

`dependent:` on an association is not a callback you write. It keeps the data consistent when a record is deleted, e.g. `has_many :comments, dependent: :destroy`, so use it as usual.

## Enums

Store an enum's values as strings, e.g. `enum :status, { draft: "draft", published: "published" }`. You SHOULD NOT map an enum to integers. An app that already stores integers can keep them.

A string reads the same in the database as in the code, so a query, a dump or a report shows `"published"`, not `1`. It also keeps its meaning when you reorder or remove a value. An integer only means something through the mapping in the model.

```ruby
class Post < ApplicationRecord
  ### Enumerations ###

  enum :status, { draft: "draft", published: "published" }
end
```

When an enum does map to integers, give every value its integer in a hash, e.g. `enum :status, { draft: 0, published: 1 }`. You MUST NOT list the values in an array, e.g. `enum :status, [:draft, :published]`. Rails then numbers them by their place in the list, so adding a value anywhere but the end changes what the stored numbers mean.

```ruby
# Don't do this
class Post < ApplicationRecord
  ### Enumerations ###

  enum :status, [:draft, :published]
end
```

## Secrets

Encrypt a column that stores a secret, e.g. an API key or an access token, with `encrypts`. Put it under `### Attributes ###`. Rails encrypts the value before it saves it, so a database dump, a backup or a logged query doesn't show the secret. The model still reads it as plain text, e.g. `integration.api_key`.

```ruby
class NewsletterServiceIntegration < ApplicationRecord
  ### Attributes ###

  encrypts :api_key

  # ...
end
```

Active Record Encryption needs its keys before the first `encrypts`. Run `bin/rails db:encryption:init`, and add the keys it prints to the app's credentials.

## Business logic

A model never builds or calls a [service object](../services/). It changes and queries its own record. Work with another service goes in an action, which takes the record as an argument.

A method on the model that builds a service would let any code holding the record call the service, e.g. a view.

```ruby
class NewsletterServiceIntegration < ApplicationRecord
  # Don't do this
  def client
    NewsletterClient.for(self)
  end
end
```

> **TODO:** Describe how you handle the rest of this.

## Testing

See [Testing: Models](../../testing/models/).
