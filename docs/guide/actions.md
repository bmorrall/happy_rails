---
title: Actions
parent: The Guide
nav_order: 6
---

# Actions

How actions are written and called.

An action is an object that does one task, e.g. archiving a post. Any code can call it, e.g. a controller, a form or a job.

Actions are the gateway to [service objects](../services/). A form, controller or job calls an action, and the action calls the services it needs, e.g. `Posts::SendNewsletter` calls `NewsletterClient`. An action has one `call` method. A service has a method for each thing it does.

An action is not a [command form](../forms/#command-forms). A command form handles what the user submits, and tells them whether it worked. An action is a separate object that does the task.

Put actions in `app/actions/`, e.g. `Posts::ArchivePost` in `app/actions/posts/archive_post.rb`.

## When to write an action

Write an action for a task that could be run from more than one place, e.g. a form, a job, the console or a rake task. Publishing a post is a good fit: a user publishes from a form, a job publishes scheduled posts, and a developer might publish one from the console to fix a problem. Each caller calls the same action, so the task works the same way everywhere.

When only one place will ever do the work, keep it there, e.g. in the form's `submit` or the job's `perform`. Move it into an action when a second caller needs it.

## Calling other actions

An action can call another action, but keep it rare. An action does the one task its caller needs. When it calls other actions, it starts to run a process, and the failures and retries of every step become its problem.

Call another action only when that action is part of the same task, and no caller would want one without the other. Its writes join the first action's transaction, as in [Transactions](#transactions).

When the work needs more than one step, run the steps from a job. A step can be an action, or code that only the job runs. When a later step can wait, enqueue a job for it, so it runs and retries on its own.

```ruby
class PublishScheduledPostJob < ApplicationJob
  def perform(post)
    Posts::PublishPost.call(post, publisher: post.scheduled_by)
    NotifySubscribersJob.perform_later(post)
  end
end
```

`Posts::PublishPost` publishes the post and does nothing else. Notifying subscribers is a separate step, so it runs in its own job.

When several forms and jobs run the same steps, see [Patterns: Multi-Step Processes](../../patterns/multi-step-processes/) for ways to share them.

An action MAY enqueue a job. The job's work doesn't run in the action, so it doesn't add a step that the action has to retry or roll back. If the action enqueues inside a transaction, make sure the job waits for the transaction to commit. See [Jobs: Enqueueing after a transaction](../jobs/#enqueueing-after-a-transaction).

When enqueuing takes more than calling the job with what the caller has, put it in an action, and start the action's name with `Enqueue`. Every caller then enqueues the jobs the same way. The name tells the caller that the work happens later, not by the time the action returns.

For example, the action enqueues one job for each post in a collection, e.g. `Posts::EnqueuePublishes`.

```ruby
module Posts
  class EnqueuePublishes < ApplicationAction
    def initialize(posts)
      @posts = posts
    end

    def call
      posts.find_each { |post| PublishScheduledPostJob.perform_later_for(post) }
    end

    private

    attr_reader :posts
  end
end
```

Or it works out the job's arguments from the records it's given, e.g. when the job takes other records than the caller has, or none at all. `Posts::EnqueueStatsRefresh` takes a post, and enqueues `RefreshNewsletterStatsJob` with the post's newsletter ID. The job takes only the ID, so it knows nothing about posts.

```ruby
module Posts
  class EnqueueStatsRefresh < ApplicationAction
    def initialize(post)
      @post = post
    end

    def call
      return unless post.newsletter_id?

      RefreshNewsletterStatsJob.perform_later(post.newsletter_id)
    end

    private

    attr_reader :post
  end
end
```

When the caller already has the job's arguments, call the job in the caller, e.g. `PublishScheduledPostJob.perform_later_for(post)`. Settings the job works out from its own arguments, e.g. when it runs, go in the job, not the action. See [Jobs: Jobs that run at a set time](../jobs/#jobs-that-run-at-a-set-time).

Leave the queue to the job. You SHOULD NOT pick it in the caller with `set(queue:)`, e.g. `NotifySubscribersJob.set(queue: :high).perform_later(post)`. Then you can read a job's queue from its class, and every caller puts it on the same queue. When the queue depends on the job's arguments, pass `queue_as` a block in the job instead. See [Jobs: Queues](../jobs/#queues).

### Errors from other actions

The actions an action calls are part of how it does its task, so its callers never see their errors. Rescue the other action's error and raise your own, as for any other error. The caller of `Posts::ArchivePost` then rescues `Posts::ArchivePost::Error` alone, and you can move `Posts::UnpublishPost` in or out without changing any caller.

```ruby
module Posts
  class ArchivePost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      ActiveRecord::Base.transaction do
        Posts::UnpublishPost.call(post) if post.published?
        post.update!(archived_at: Time.zone.now)
        post.comments.update_all(locked: true, updated_at: Time.zone.now)
      end
    rescue ActiveRecord::RecordInvalid, Posts::UnpublishPost::Error => e
      raise Error, e.message
    end
  end
end
```

Rescue the other action's error outside the transaction block. Its writes join your transaction. If you rescue its error inside the block and carry on, nothing rolls back, and its half-done writes commit with yours. See [Rolling back](#rolling-back). The exception is an action that opens its own savepoint, as in [Carrying on when another action fails](#carrying-on-when-another-action-fails). Its writes roll back on their own, so you can rescue its error inside the block.

Raise the error for the same cause. When the other action raises its class for one cause, raise your own class for that cause, not your plain `Error`, e.g. `rescue Posts::SendNewsletter::ServiceError` then `raise ServiceError, e.message`. Put that `rescue` before the one for the other action's `Error`. A controller that rescues your class for the service failing then still sees it, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing). See [Error handling](#error-handling) for error classes for each cause.

### Carrying on when another action fails

Sometimes your action can still do its task when another action it calls fails, e.g. `Posts::AddCoauthors` adds the co-authors it can, and skips an email whose legacy user won't import. Your action MAY carry on, when every caller wants the other action tried and the task is still done without it. Rescue the other action's `Error` alone, and carry on, instead of raising your own. Any other error is a bug, so let it raise. The other action opens its own savepoint, as below, so add one if it doesn't.

You SHOULD report the error you rescue. Nothing else shows that the other action failed: the user doesn't see it, and the job doesn't fail. This differs from an expected outcome that a form shows the user, which you don't have to report. When the failure is an outcome the app expects, e.g. a legacy user whose data won't import, you SHOULD tag the report `low_priority`, e.g. `tags: ["low_priority"]`, as for any expected outcome. See [Honeybadger: Reporting errors](../gems/honeybadger/#reporting-errors).

```ruby
module Posts
  class AddCoauthors < ApplicationAction
    # ...

    def call
      emails.each do |email|
        user = User.find_or_initialize_by_any_email(email)
        import_user(user)
        next unless user.persisted?

        post.coauthorships.find_or_create_by!(user:)
      end
    end

    private

    attr_reader :post, :emails

    def import_user(user)
      Users::ImportLegacyUser.call(user)
    rescue Users::ImportLegacyUser::Error => e
      Honeybadger.notify(e, context: { post: post.to_honeybadger_context }, tags: ["low_priority"])
    end
  end
end
```

The action that callers carry on past keeps its writes to itself. Wrap its writes in `ActiveRecord::Base.transaction(requires_new: true)`, even when it writes once, and rescue errors to raise its `Error` outside that block. Its caller might have a transaction open. Rails joins a plain nested transaction block to the one around it, so a failure rolls nothing back until the outermost transaction does. If the caller rescues the error and carries on, the half-done writes commit with the caller's. One `save!` can run several statements, e.g. callbacks and autosaved associations, so this applies to an action that writes once too. If the action's `Error` wraps a database error, e.g. `ActiveRecord::RecordNotUnique`, PostgreSQL has aborted the whole transaction, and the caller's next write fails too. `requires_new: true` adds a savepoint when a transaction is open, and opens a transaction when none is. When the action fails, only its own writes roll back, and its caller can rescue the error anywhere, even inside its own transaction.

```ruby
module Users
  class ImportLegacyUser < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      return if user.persisted?

      legacy_user = LegacyUser.find_by(email: user.email)
      return if legacy_user.nil?

      ActiveRecord::Base.transaction(requires_new: true) do
        user.update!(name: legacy_user.full_name)
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
```

You MUST NOT pass `requires_new: true` in any other action's transaction. Without it, the action's writes commit or roll back with the caller's. When a caller starts carrying on past an action, add the savepoint to that action. A `Record` action commits on its own, so it needs no savepoint, as in [Records that survive a rollback](#records-that-survive-a-rollback).

When only some callers want to carry on, the other action isn't part of your task. Run it as a separate step, as in [Patterns: Multi-Step Processes](../../patterns/multi-step-processes/).

## Naming

Put each action in a module named after the resource it works on, in the plural, like its controller, e.g. `Posts`. Name the action after the task, starting with a verb. The name can include the resource as well, e.g. `Posts::ArchivePost`. The module groups every action for a resource in one directory, and the name says what the action does.

```ruby
module Posts
  class ArchivePost < ApplicationAction
    # ...
  end
end
```

## Calling an action

Every action responds to `call`. Callers use the class method, e.g. `Posts::ArchivePost.call(post)`, not `new` and then `call`. The class method builds the action with its arguments and runs it, so every action is called the same way.

Give every action a base class, `ApplicationAction`, in `app/actions/application_action.rb`. It defines the class method `call` once, so each action only writes `initialize` and an instance method `call`.

```ruby
class ApplicationAction
  def self.call(...)
    new(...).call
    nil
  end
end
```

```ruby
module Posts
  class ArchivePost < ApplicationAction
    def initialize(post)
      @post = post
    end

    def call
      ActiveRecord::Base.transaction do
        post.update!(archived_at: Time.zone.now)
        post.comments.update_all(locked: true, updated_at: Time.zone.now)
      end
    end

    private

    attr_reader :post
  end
end
```

## Layout

Write the parts of an action in this order:

1. Error classes, e.g. `class Error < StandardError; end`
2. `include` lines, e.g. `include ValidatedCallable`
3. Validations
4. `initialize`
5. `call`
6. `private`, then the `attr_reader`s, then any private methods

Every action then reads the same way. The top says how it can fail and what it checks, and `call` sits right after `initialize`, so you see the task next to what it's given. Leave out a part the action doesn't have.

You MUST NOT add comment headings, as in a model. An action has one public method, and the order alone is enough.

```ruby
module Posts
  class PublishPost < ApplicationAction
    class Error < StandardError; end

    include ValidatedCallable

    validates :post, :publisher,
      presence: true,
      unmodified: { allow_blank: true }

    def initialize(post, publisher:)
      @post = post
      @publisher = publisher
    end

    def call
      # ...
    end

    private

    attr_reader :post, :publisher
  end
end
```

### Private methods

Name a private method that builds, creates or changes a record after the action it takes, starting with a verb. You MUST NOT name it like a variable, e.g. `publication`. A name like that reads as a value, so you can't tell from `call` that the step writes to the database. A verb says what the step does, and which steps need to run inside the transaction or the lock.

Use `build_` for a method that builds a record without saving it, e.g. `build_publication`, `create_` for one that saves a new record, e.g. `create_publication`, and `update_` for one that changes a saved record, e.g. `update_post`. Use another verb when it says more, e.g. `increment_published_posts_count` for a method that calls `increment!`.

```ruby
# Don't
def publication
  post.publications.create!(publisher:)
end

def published_posts_count
  publisher.increment!(:published_posts_count)
end

# Do
def create_publication
  post.publications.create!(publisher:)
end

def increment_published_posts_count
  publisher.increment!(:published_posts_count)
end
```

`build_` covers any object a method makes new each time it's called, not only a record, e.g. `build_newsletter_client` for a method that returns `NewsletterClient.new`. Each call gives a new object, and the name says so. A memoised method gives back the same object every time, so it reads as a value. Name it like a variable, e.g. `newsletter_client` for `@newsletter_client ||= NewsletterClient.new`.

```ruby
# New each call
def build_newsletter_client
  NewsletterClient.new
end

# Memoised
def newsletter_client
  @newsletter_client ||= NewsletterClient.new
end
```

## Arguments

Pass an action the records it works on, not their IDs, e.g. `Posts::ArchivePost.call(post)`, not `Posts::ArchivePost.call(post.id)`. The caller finds the records, e.g. a controller loads the post, or a job gets it as an argument. The action never looks a record up, so it doesn't have to decide which records the caller is allowed to reach.

Make the resource the action works on the first positional argument. Pass every other argument as a keyword, e.g. `Posts::PublishPost.call(post, publisher: current_user)`. The call then reads as the task and the record it works on, and each other value is named where it is passed. You can also add a keyword later without changing the order of the arguments in every caller.

```ruby
module Posts
  class PublishPost < ApplicationAction
    def initialize(post, publisher:)
      @post = post
      @publisher = publisher
    end

    # ...

    private

    attr_reader :post, :publisher
  end
end
```

A job finds the records from its own arguments, e.g. the user who scheduled the post.

```ruby
class PublishScheduledPostJob < ApplicationJob
  def perform(post)
    Posts::PublishPost.call(post, publisher: post.scheduled_by)
  end
end
```

When an action needs a user, name the keyword after the role the user plays, e.g. `publisher:`. See [Principles: The signed-in user](../principles/#the-signed-in-user).

You SHOULD NOT pass a record with unsaved changes to an action. The action can't tell which values are saved. When it saves the record, e.g. with `update!`, it saves the caller's changes too, without anyone asking it to. When it locks the record, `with_lock` raises an error instead, as in [Locks](#locks). Save the changes first, or pass the new values to the action as keywords, e.g. `Posts::PublishPost.call(post, publisher:, title:)`, and let the action set them.

The exception is an action whose task is to save a new record the caller built, e.g. `Posts::CopyPost`, which saves a copy of a post with copies of its associations. Then saving every value is the point.

```ruby
# Don't
post.title = title
Posts::PublishPost.call(post, publisher: current_user)

# Do
Posts::PublishPost.call(post, publisher: current_user, title:)
```

When the action builds a query on a record's association in more than one step, e.g. `post.comments.where(locked: false)`, call a method on the model instead, e.g. `post.unlocked_comments`, not `post.comments.unlocked`. Do the same for a query that starts from a class, e.g. `Comment.on_posts(posts)`, not `Comment.where(post: posts)`. See [Models: Scopes and queries](../models/#scopes-and-queries).

### Many records

When an action works on many records, pass the records in, e.g. `Posts::ArchivePosts.call(author.posts)`, not their IDs. Name the action in the plural. The caller picks the records, as it does for one record, and the action works on every record it's given.

Pass a relation or an association, or an array of records, but pick one for each action, and have every caller pass the same kind. You MUST NOT let the action accept both, e.g. by checking `posts.is_a?(Array)`. A relation and an array don't respond to the same methods, e.g. `update_all` and `find_each` only work on a relation, so code written for one breaks on the other.

Prefer a relation when there could be many records. An array loads every record into memory at once. A relation lets the action write them all in one statement, or load them in batches.

When the task can be done in SQL, write every record at once, e.g. with `update_all`. Wrap the writes in a transaction, as for any action that writes more than once.

`update_all` and `delete_all` skip the model's callbacks and validations, and `delete_all` skips `dependent:` too. Check the model before you use them. If a callback runs when an attribute you change is saved, loop over the records instead, as below. For example, `Post` sets `published_at` in a callback when a post is published, so `posts.update_all(status: :published)` would leave `published_at` blank.

`update_all` doesn't set `updated_at` either. Pass it yourself, e.g. `update_all(locked: true, updated_at: Time.zone.now)`, so the records show when they last changed, and caches keyed on `updated_at` expire.

```ruby
module Posts
  class ArchivePosts < ApplicationAction
    def initialize(posts)
      @posts = posts
    end

    def call
      now = Time.zone.now

      ActiveRecord::Base.transaction do
        Comment.on_posts(posts).update_all(locked: true, updated_at: now)
        posts.update_all(archived_at: now, updated_at: now)
      end
    end

    private

    attr_reader :posts
  end
end
```

Update the relation's own records last, e.g. the posts after their comments. A relation is a query, so each statement runs it again. Say the caller passed `author.posts.where(archived_at: nil)`. If the posts were archived first, the query would then find no posts, and no comments would be locked.

When each record needs the model's validations, callbacks or a lock, load them with `find_each`, or loop with `each` over an array, and call the single-record action for each one, e.g. `posts.find_each { |post| Posts::ArchivePost.call(post) }`. Avoid wrapping the loop in a transaction. Each record then commits on its own, so a long run doesn't hold its locks until the end.

Prefer `find_each` to `each` when you loop over a relation. `each` loads every record at once, and `find_each` loads them in batches of 1,000, so memory stays flat however many records match. Note that `find_each` orders the records by their primary key, and ignores any order on the relation.

## Authorisation and validation

An action runs outside a request, so it doesn't authorise the user or validate what they submitted. The caller does that before it calls the action. A controller authorises the request, and a form validates the user's input. When a job calls the action, the request that enqueued the job has already done both. The action trusts its caller, and does its task.

### Checking arguments

You MAY add a last check that an action was given proper arguments, as a safety check for developers. Put it in a `ValidatedCallable` concern in `app/actions/concerns/validated_callable.rb`. It adds `ActiveModel::Validations` to the action, and runs `validate!` before `call`.

```ruby
module ValidatedCallable
  extend ActiveSupport::Concern

  include ActiveModel::Validations

  class_methods do
    def call(...)
      action = new(...)
      action.validate!
      action.call
      nil
    end
  end
end
```

Include it in the actions that need it, and validate the arguments as you would a model's attributes.

```ruby
module Posts
  class PublishPost < ApplicationAction
    include ValidatedCallable

    validates :post, :publisher,
      presence: true,
      unmodified: { allow_blank: true }

    # ...
  end
end
```

`unmodified:` checks that a record argument has no unsaved changes, as in [Arguments](#arguments). It uses an `UnmodifiedValidator` in `app/validators/`. See [Validators: UnmodifiedValidator](../validators/#unmodifiedvalidator).

When the action needs a record argument to be saved, e.g. it passes the record to a job, validate it with `persisted:`, e.g. `persisted: { allow_blank: true }`. It uses a `PersistedValidator`. See [Validators: PersistedValidator](../validators/#persistedvalidator).

The check catches a caller that breaks the rule, e.g. a form that sets `post.title` before it calls the action. It fails in the caller's specs, before `with_lock` or `update!` can hit the changes.

A failed check means a developer called the action wrongly. It is a bug, not an outcome the user can expect, so you MUST NOT use it to control what the app does next. You MUST NOT rescue `ActiveModel::ValidationError` when you call an action, and you MUST NOT raise it again as the action's `Error`. Let it fail loudly, so the bug shows up in your specs and error reports. When a user can cause the failure, check it in the form instead, where the user can see the error.

See [Testing: Actions](../../testing/actions/#checking-arguments) for specs of actions that check their arguments.

## Return values

An action does its task and returns nothing. The caller doesn't check a result, so you MUST NOT return one from `call`, and you MUST NOT use the value it returns. `ApplicationAction.call` returns `nil`, so a caller can't come to depend on whatever the last line of `call` returns.

```ruby
Posts::ArchivePost.call(post)

redirect_to posts_path,
  notice: "Post was archived."
```

When a caller needs a value from the action's work, e.g. an ID from another service, save the value on a record the caller holds. The caller reads it from the record after the call, e.g. `@post.newsletter_id` after `Posts::SendNewsletter.call(@post)`. The value usually belongs on a record anyway, because the app needs it again later.

When the other service accepts an ID from you, generate the ID in the caller and pass it to the action, e.g. `newsletter_id = SecureRandom.uuid` then `Posts::SendNewsletter.call(@post, newsletter_id:)`. The caller then knows the ID before the action runs.

When an API client tracks a request to another service, create a record for the request first, with an ID of your own, e.g. `has_secure_token :reference` on `NewsletterDelivery`. Send your ID to the service, and give the client your ID, not the service's. Then the client has an ID even if the call fails, and never depends on the other service.

You MUST NOT pass a value back through a block or a result object. Both are a return value in disguise.

See [Patterns: Values from Actions](../../patterns/values-from-actions/) for examples and other options, and [Patterns: Records from a Legacy Database](../../patterns/records-from-a-legacy-database/) for an action that finds or copies a record the caller then uses.

## Error handling

If the task fails, raise an error, e.g. with `update!`, rather than returning `false`. Let an error that no caller is meant to handle pass through as it is.

When a caller is meant to handle an error, write a custom `Error` class inside the action, and inherit it from `StandardError`. In `call`, rescue the errors the caller is meant to handle and raise them again as the action's `Error`. The caller then rescues one error class, e.g. `Posts::ArchivePost::Error`, and doesn't need to know which errors the action's code can raise. Ruby keeps the original error as the new error's `cause`, so a report of the new error shows the original too. See [Honeybadger: Reporting errors](../gems/honeybadger/#reporting-errors) for reporting an error the caller rescues.

```ruby
module Posts
  class ArchivePost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      ActiveRecord::Base.transaction do
        post.update!(archived_at: Time.zone.now)
        post.comments.update_all(locked: true, updated_at: Time.zone.now)
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
```

When the user or a developer caused the failure, e.g. invalid data, rescue the action's `Error` where the work is done, in a form or a job, as in [Controllers and Routes: Rescuing errors](../controllers/#rescuing-errors).

```ruby
def submit
  return false unless valid?

  Posts::ArchivePost.call(post)
  post
rescue Posts::ArchivePost::Error
  errors.add(:base, "Post could not be archived.")
  false
end
```

An action can fail for more than one cause, and its callers might handle each cause differently. Give each cause its own error class, and inherit it from the action's `Error`. A caller rescues the class for the cause it handles, or `Error` to handle them all.

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    class Error < StandardError; end
    class RejectedError < Error; end
    class ServiceError < Error; end

    # ...

    def call
      response = NewsletterClient.new.create_newsletter(title: post.title, body: post.body)
      post.update!(newsletter_id: response.id)
    rescue NewsletterClient::UnprocessableError => e
      raise RejectedError, e.message
    rescue NewsletterClient::Error => e
      raise ServiceError, e.message
    end
  end
end
```

The newsletter service rejects a post it can't send, e.g. one with no title. The user can fix that, so a form rescues `RejectedError` and shows it. When the service itself fails, e.g. it returns a 500 or times out, the user can't fix it. A controller that calls the action rescues `ServiceError` with `rescue_from`, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing).

Raise the class for the service failing, e.g. `ServiceError`, for the client's base error class, e.g. `NewsletterClient::Error`, not a list of its errors. Then every failure of the service, e.g. a server error, a timeout or a refused connection, reaches the controller's handler. Rescue the causes the user can fix first, because Ruby uses the first `rescue` that matches. An error the action doesn't wrap is a bug, so it fails as normal.

### Shared errors

Several actions can call the same service for related tasks, e.g. `Posts::SendPublicNewsletter` and `Posts::SendPrivateNewsletter` both create a newsletter through `NewsletterClient`. They fail for the same causes, and their callers handle each cause the same way. Writing the same error classes in each action, and a handler for each in the controller, repeats the same code.

You MAY define the error classes once, in a base class for the group. Inherit the base class from `ApplicationAction`, and name it after the group, ending in `Action`, e.g. `Posts::NewsletterAction` in `app/actions/posts/newsletter_action.rb`. The name tells you it isn't a task, so no one calls it. Inherit each action in the group from it, and leave out the action's own error classes.

```ruby
module Posts
  class NewsletterAction < ApplicationAction
    class Error < StandardError; end
    class RejectedError < Error; end
    class ServiceError < Error; end
  end
end
```

```ruby
module Posts
  class SendPrivateNewsletter < NewsletterAction
    # ...

    def call
      response = NewsletterClient.new.create_private_newsletter(title: post.title, body: post.body)
      post.update!(newsletter_id: response.id)
    rescue NewsletterClient::UnprocessableError => e
      raise RejectedError, e.message
    rescue NewsletterClient::Error => e
      raise ServiceError, e.message
    end
  end
end
```

Ruby looks up a constant through the superclass, so `Posts::SendPrivateNewsletter::ServiceError` is `Posts::NewsletterAction::ServiceError`. Every action in the group raises the same classes. In a caller, rescue them by the base class's name, e.g. `rescue Posts::NewsletterAction::RejectedError`, so the caller doesn't look like it handles one action alone. A controller then needs one handler for the whole group, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing).

An action that shares its errors SHOULD NOT define error classes. Put every class the group raises in the base class, so you can see every way the group fails in one place, and every action in it fails the same ways.

The base class MAY also hand its actions the service, in a private method that builds it, yields it to a block, and turns the service's errors into the group's. Name it `with_` and the service, e.g. `with_newsletter_client` for `NewsletterClient`. When the service is in a module, put the module's name first, e.g. `with_newsletter_client` for `Newsletter::Client`, not `with_client`. The name then says which service it builds. When the group calls more than one service, give each service its own method. Each action then makes its call in the block, instead of repeating the same `rescue`s. When you add a cause, you map it once, and no action in the group can miss it. When the service is built from a record, e.g. `NewsletterClient.for(integration)`, only the method changes.

```ruby
module Posts
  class NewsletterAction < ApplicationAction
    class Error < StandardError; end
    class RejectedError < Error; end
    class ServiceError < Error; end

    private

    def with_newsletter_client
      yield NewsletterClient.new
    rescue NewsletterClient::UnprocessableError => e
      raise RejectedError, e.message
    rescue NewsletterClient::Error => e
      raise ServiceError, e.message
    end
  end
end
```

```ruby
module Posts
  class SendPrivateNewsletter < NewsletterAction
    # ...

    def call
      newsletter = with_newsletter_client do |client|
        client.create_private_newsletter(title: post.title, body: post.body)
      end
      post.update!(newsletter_id: newsletter.id)
    end
  end
end
```

Put only the service call in the block. A save that fails, e.g. `update!`, isn't the service failing, so it passes through as normal. When the action saves between two requests, as in [Services: One request per method](../services/#one-request-per-method), use a block for each request. The method raises inside `rescue`, so Ruby keeps the service's error as the `cause`, as in [Error handling](#error-handling).

When the base class has the method, an action in the group MUST NOT build the service itself, e.g. with `NewsletterClient.new`. Its calls would then skip the group's errors.

The base class MAY also take the record its namespace is named after, e.g. the post for `Posts::NewsletterAction`. An action under `Posts` already takes the post as its first argument, as in [Arguments](#arguments), so every action in the group starts the same way. Define `initialize` and its `attr_reader` in the base class, and leave them out of each action. Its file then holds only the task. Put any validations of that record in the base class too, e.g. `validates :post, presence: true`.

```ruby
module Posts
  class NewsletterAction < ApplicationAction
    class Error < StandardError; end
    # ...

    def initialize(post)
      @post = post
    end

    private

    attr_reader :post

    # ...
  end
end
```

When an action needs more arguments, it defines its own `initialize`. Call `super` with the record, then set only the action's own keywords, e.g. `settings:`. The base class then stays the one place that sets the record.

```ruby
module Posts
  class SendPublicNewsletter < NewsletterAction
    def initialize(post, settings:)
      super(post)
      @settings = settings
    end

    def call
      # ...
    end

    private

    attr_reader :settings
  end
end
```

When one action really needs a finer cause, it MAY add a subclass of a shared cause, e.g. `class TimeoutError < ServiceError; end` in `Posts::SendPrivateNewsletter`. It still inherits from the shared class, so a caller that rescues `Posts::NewsletterAction::ServiceError` still handles it. When the group has a `with_` method, rescue the finer cause inside its block, e.g. `rescue NewsletterClient::TimeoutError => e` then `raise TimeoutError, e.message`. The block's `rescue` runs first, and the method lets the action's own error pass through.

You MUST NOT inherit an error class in the action from the base class's `Error`, e.g. `class NewCauseError < Error; end` or `class Error < BaseAction::Error; end`. A new cause on one action means the group no longer fails for the same causes, and callers that rescue each shared cause miss it. A new `Error` is worse: the base class's other error classes don't inherit from it, so a caller that rescues the action's `Error` misses them. When an action needs a new cause, add its class to the base class.

Share errors only when no caller needs to know which action in the group failed. A caller that rescues `Posts::NewsletterAction::ServiceError` can't tell. When a caller needs to know, give each action its own error classes.

Actions that share errors MUST NOT call each other. They do related tasks with the same service, so work that needs more than one of them is a process. Run them in turn from a form or a job, as in [Calling other actions](#calling-other-actions). An action also couldn't wrap the other's errors, as in [Errors from other actions](#errors-from-other-actions). Its own class is the same class it would rescue, so callers couldn't tell which action failed.

## Transactions

When an action writes more than once, wrap the writes in a transaction, so either they all save or none do. Then the action is safe whoever calls it, and no caller has to remember to wrap it. An action that writes once doesn't need a transaction.

```ruby
def call
  ActiveRecord::Base.transaction do
    post.update!(archived_at: Time.zone.now)
    post.comments.update_all(locked: true, updated_at: Time.zone.now)
  end
end
```

A form or a job can still wrap several actions in one transaction. Rails joins a nested `transaction` block to the one around it, so the action's writes commit or roll back with the caller's. Open a transaction in a form or a job only to combine several writes into one unit, e.g. two actions, or an action and the form's own save.

```ruby
def submit
  return false unless valid?

  ActiveRecord::Base.transaction do
    Posts::PublishPost.call(post, publisher: current_user)
    Posts::ArchivePost.call(previous_post)
  end

  post
end
```

### Locks

When an action relies on a lock, take the lock inside the action with `with_lock`. It opens a transaction, or joins the caller's, and reloads the record. Keep the lock next to the code it protects, not in the caller.

`with_lock` raises an error if the record has unsaved changes, because reloading would throw them away. This is one reason not to [pass a record with unsaved changes](#arguments) to an action. When the action needs new values, set them inside the lock, so the check and the whole update happen together.

You MAY check the condition before you take the lock, to skip the lock when the work is plainly not needed. Always check it again inside the lock, because another process might have changed the record while you waited for it.

```ruby
module Posts
  class PublishPost < ApplicationAction
    # ...

    def call
      return if post.published?

      post.with_lock do
        next if post.published?

        post.update!(status: :published)
        post.publications.create!(publisher:)
      end
    end
  end
end
```

Use `next` to leave a `transaction` or `with_lock` block early, not `return`. What a `return` inside the block does has changed between Rails versions, and depends on the app's config: it might commit or roll back. `next` ends the block, and the transaction commits as normal.

When the check fails, decide what the caller needs to know. If the work is already done, e.g. the post is already published, do nothing. The action is then safe to retry, e.g. from a job. If the caller needs to know, e.g. to show a form error, raise the action's `Error`. Do the same thing in the check before the lock and the check inside it, so the result doesn't depend on timing.

When an action locks more than one record, lock them in the same order every time, the parent before its children, e.g. the post before its comments. Two processes that lock in different orders can deadlock.

### Other services

You MUST NOT call another service inside a transaction. The transaction keeps its locks and its database connection while it waits for the reply. A rollback can't undo the call either. Call the service first, then save its reply in the transaction.

```ruby
def call
  response = NewsletterClient.new.create_newsletter(title: post.title, body: post.body)

  ActiveRecord::Base.transaction do
    post.update!(newsletter_id: response.id)
    post.publications.create!(publisher:)
  end
end
```

This includes the caller's transaction. Rails joins a nested `transaction` block to the one around it, so calling the service before the action's own transaction isn't enough. If a form or another action calls this action inside a transaction, the service call is inside it too.

When the action needs the reply, you MUST NOT call it inside a transaction. Include a `NonTransactionalCallable` concern, in `app/actions/concerns/non_transactional_callable.rb`. It raises an error when the action is called inside a transaction, so the first caller that wraps it fails in its specs. The transactions that wrap each spec can't be joined, so the check ignores them.

```ruby
module NonTransactionalCallable
  extend ActiveSupport::Concern

  class_methods do
    def call(...)
      if ActiveRecord::Base.connection.current_transaction.joinable?
        raise "#{name} calls another service, so it can't run inside a transaction"
      end

      super
    end
  end
end
```

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    include NonTransactionalCallable

    # ...
  end
end
```

When the action doesn't need the service's reply, you MUST NOT call the service from the action. Enqueue a job that calls it instead, e.g. `NotifySubscribersJob`. The job waits until the outermost transaction commits, as in [Jobs: Enqueueing after a transaction](../jobs/#enqueueing-after-a-transaction), so it is safe however the action is called.

When a call to another service needs to be retried if it fails, run it in a job of its own that does nothing else, e.g. `NotifySubscribersJob`. A job retries all of `perform`, so a retry then repeats only that call. The steps before it have already committed, and don't run again.

When a user is waiting for the reply, call the action directly, and you MUST NOT retry it. The user sees that it failed and can try again, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing).

### Work after the commit

Some work needs to wait until the records are committed, e.g. a job that loads them, or a Turbo broadcast that shows them. An action can't do this after its own transaction block, because its caller might still have a transaction open.

For a job, set `enqueue_after_transaction_commit` in the job class, as in [Jobs: Enqueueing after a transaction](../jobs/#enqueueing-after-a-transaction). For any other work, wrap it in `ActiveRecord.after_all_transactions_commit`. The block runs once the outermost transaction commits, never if it rolls back, and at once if no transaction is open.

```ruby
def call
  ActiveRecord::Base.transaction do
    post.update!(archived_at: Time.zone.now)
    post.comments.update_all(locked: true, updated_at: Time.zone.now)
  end

  ActiveRecord.after_all_transactions_commit do
    post.broadcast_refresh
  end
end
```

### Rolling back

You MUST NOT raise `ActiveRecord::Rollback` in an action. In a nested block, Rails swallows it: the block stops, but the caller's transaction carries on and commits. Raise a real error instead, so the whole transaction rolls back.

Rescue errors to raise them again as the action's `Error` outside the transaction block, as in [Error handling](#error-handling). By then the transaction has already rolled back.

You MUST NOT rescue a database error inside a `transaction` or `with_lock` block and carry on, e.g. `ActiveRecord::StatementInvalid` or its subclass `ActiveRecord::RecordNotUnique`. In PostgreSQL, a failed statement aborts the transaction, and every later statement in it fails until it rolls back. Let the error leave the block, so the whole transaction rolls back.

You MAY rescue other errors inside the block, when the action can recover from them, e.g. `Post::UnreadableDataError` from a stored report that no longer parses. Nothing failed in the database, so the transaction carries on as normal. Writes made in the block before the error still commit, so rescue inside the block only when they need to stay saved. Rescue another action's errors outside the block, as in [Errors from other actions](#errors-from-other-actions), because its half-done writes would commit with yours. You MAY rescue them inside the block when the other action opens its own savepoint, as in [Carrying on when another action fails](#carrying-on-when-another-action-fails).

### Records that survive a rollback

Some actions save a fact about what happened, e.g. whether a check passed or failed. That fact needs to stay saved even when other work fails. Start the name of these actions with `Record`, e.g. `Posts::RecordLinkCheck`, which saves `link_check_status` on the post. The name tells the caller that this write stays saved when the rest rolls back.

You MUST NOT call a `Record` action inside a transaction. Call it before or after the transaction block. A write inside a transaction rolls back with it, even in a nested block with `requires_new: true`. That only adds a savepoint, which rolls back when the outer transaction does.

Include `NonTransactionalCallable` in every `Record` action, as in [Other services](#other-services). A caller that wraps the action in a transaction then fails in its specs.

```ruby
# app/actions/posts/record_link_check.rb
module Posts
  class RecordLinkCheck < ApplicationAction
    include NonTransactionalCallable

    # ...
  end
end

# app/forms/publish_post_form.rb
class PublishPostForm < ApplicationForm
  # ...

  def submit
    return false unless valid?

    Posts::RecordLinkCheck.call(post)
    return false if post.link_check_failed?

    ActiveRecord::Base.transaction do
      Posts::PublishPost.call(post, publisher: current_user)
      Posts::ArchivePost.call(previous_post)
    end

    post
  end
end
```

The link check commits on its own. If `Posts::ArchivePost` fails, the publish rolls back, but the link check stays saved. When later work depends on the result, read it from the record, e.g. `post.link_check_failed?`.

To record that the transaction itself failed, call the `Record` action in a `rescue` or `ensure` on the caller's method. The transaction has rolled back by then, so the write stays saved.

## Testing

See [Testing: Actions](../../testing/actions/).
