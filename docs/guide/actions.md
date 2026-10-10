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

Write an action for a task that could be run from more than one place, e.g. a form, a job, the console or a rake task. Publishing a post is a good fit: a user publishes from a form, a job publishes scheduled posts, and a developer may publish one from the console to fix a problem. Each caller calls the same action, so the task works the same way everywhere.

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

An action can enqueue a job. The job's work doesn't run in the action, so it doesn't add a step that the action has to retry or roll back. If the action enqueues inside a transaction, make sure the job waits for the transaction to commit. See [Jobs: Enqueueing after a transaction](../jobs/#enqueueing-after-a-transaction).

When enqueuing a job takes more than a plain `perform_later`, e.g. working out when the job should run and what it should run with, put it in an action, and start the action's name with `Enqueue`, e.g. `Posts::EnqueuePublish`. Every caller then enqueues the job the same way. The name tells the caller that the work happens later, not by the time the action returns. For a plain `perform_later`, enqueue the job in the caller.

```ruby
module Posts
  class EnqueuePublish < ApplicationAction
    def initialize(post)
      @post = post
    end

    def call
      PublishScheduledPostJob.set(wait_until: post.publish_at).perform_later(post)
    end

    private

    attr_reader :post
  end
end
```

### Errors from other actions

The actions an action calls are part of how it does its task, so its callers never see their errors. Rescue the other action's error and raise your own, as for any other error. The caller of `Posts::ArchivePost` then rescues `Posts::ArchivePost::Error` alone, and you can move `Posts::UnpublishPost` in or out without changing any caller.

```ruby
module Posts
  class ArchivePost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      return if post.archived_at?

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

Rescue the other action's error outside the transaction block. Its writes join your transaction. If you rescue its error inside the block and carry on, nothing rolls back, and its half-done writes commit with yours. See [Rolling back](#rolling-back).

Raise the error for the same cause. When the other action raises a `ServiceError`, raise your own `ServiceError`, not your plain `Error`, e.g. `rescue Posts::SendNewsletter::ServiceError` then `raise ServiceError, e.message`. Put that `rescue` before the one for the other action's `Error`. A controller that rescues your `ServiceError` then still sees the service failing, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing). See [Error handling](#error-handling) for error classes for each cause.

If your action should carry on when the other action fails, the other action isn't part of your task. Run it as a separate step from a job instead.

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
      return if post.archived_at?

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

Don't add comment headings, as in a model. An action has one public method, and the order alone is enough.

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

## Arguments

Pass an action the records it works on, never their IDs, e.g. `Posts::ArchivePost.call(post)`, not `Posts::ArchivePost.call(post.id)`. The caller finds the records, e.g. a controller loads the post, or a job gets it as an argument. The action never looks a record up, so it doesn't have to decide which records the caller is allowed to reach.

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

Never pass a record with unsaved changes to an action. The action can't tell which values are saved. When it saves the record, e.g. with `update!`, it saves the caller's changes too, without anyone asking it to. When it locks the record, `with_lock` raises an error instead, as in [Locks](#locks). Save the changes first, or pass the new values to the action as keywords, e.g. `Posts::PublishPost.call(post, publisher:, title:)`, and let the action set them.

```ruby
# Don't
post.title = title
Posts::PublishPost.call(post, publisher: current_user)

# Do
Posts::PublishPost.call(post, publisher: current_user, title:)
```

When the action builds a query on a record's association in more than one step, e.g. `post.comments.where(locked: false)`, call a method on the model instead, e.g. `post.unlocked_comments`, not `post.comments.unlocked`. Do the same for a query that starts from a class, e.g. `Comment.on_posts(posts)`, not `Comment.where(post: posts)`. See [Models: Scopes and queries](../models/#scopes-and-queries).

### Many records

When an action works on many records, pass the records in, e.g. `Posts::ArchivePosts.call(author.posts)`, never their IDs. Name the action in the plural. The caller picks the records, as it does for one record, and the action works on every record it's given.

Pass a relation or an association, or an array of records, but pick one for each action, and have every caller pass the same kind. Don't let the action accept both, e.g. by checking `posts.is_a?(Array)`. A relation and an array don't respond to the same methods, e.g. `update_all` and `find_each` only work on a relation, so code written for one breaks on the other.

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

You may add a last check that an action was given proper arguments, as a safety check for developers. Put it in a `ValidatedCallable` concern in `app/actions/concerns/validated_callable.rb`. It adds `ActiveModel::Validations` to the action, and runs `validate!` before `call`.

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

The check catches a caller that breaks the rule, e.g. a form that sets `post.title` before it calls the action. It fails in the caller's specs, before `with_lock` or `update!` can hit the changes.

A failed check means a developer called the action wrongly. It is a bug, not an outcome the user can expect, so never use it to control what the app does next. Never rescue `ActiveModel::ValidationError` from an action, and never raise it again as the action's `Error`. Let it fail loudly, so the bug shows up in your specs and error reports. When a user can cause the failure, check it in the form instead, where the user can see the error.

Don't test the argument checks in request or job specs, e.g. that `Posts::PublishPost` raises `ActiveModel::ValidationError` for a post with unsaved changes. Every spec that calls the action already runs them, and fails if the controller or job passes the wrong arguments. Test each validator once, in its own spec.

## Return values

An action does its task and returns nothing. The caller doesn't check a result, so don't return one from `call`, and don't use the value it returns. `ApplicationAction.call` returns `nil`, so a caller can't come to depend on whatever the last line of `call` returns.

```ruby
Posts::ArchivePost.call(post)

redirect_to posts_path,
  notice: "Post was archived."
```

When a caller needs a value from the action's work, e.g. an ID from another service, save the value on a record the caller holds. The caller reads it from the record after the call, e.g. `@post.newsletter_id` after `Posts::SendNewsletter.call(@post)`. The value usually belongs on a record anyway, because the app needs it again later.

When the other service accepts an ID from you, generate the ID in the caller and pass it to the action, e.g. `newsletter_id = SecureRandom.uuid` then `Posts::SendNewsletter.call(@post, newsletter_id:)`. The caller then knows the ID before the action runs.

When an API client tracks a request to another service, create a record for the request first, with an ID of your own, e.g. `has_secure_token :reference` on `NewsletterDelivery`. Send your ID to the service, and give the client your ID, not the service's. Then the client has an ID even if the call fails, and never depends on the other service.

Don't pass a value back through a block or a result object. Both are a return value in disguise.

See [Patterns: Values from Actions](../../patterns/values-from-actions/) for examples and other options.

## Error handling

If the task fails, raise an error, e.g. with `update!`, rather than returning `false`. Let an error that no caller should handle pass through as it is.

When a caller is meant to handle an error, write a custom `Error` class inside the action, and inherit it from `StandardError`. In `call`, rescue the errors the caller should handle and raise them again as the action's `Error`. The caller then rescues one error class, e.g. `Posts::ArchivePost::Error`, and doesn't need to know which errors the action's code can raise. Ruby keeps the original error as the new error's `cause`, so a report of the new error shows the original too. See [Honeybadger: Reporting errors](../gems/honeybadger/#reporting-errors) for reporting an error the caller rescues.

```ruby
module Posts
  class ArchivePost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      return if post.archived_at?

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

An action can fail for more than one cause, and its callers may handle each cause differently. Give each cause its own error class, and inherit it from the action's `Error`. A caller rescues the class for the cause it handles, or `Error` to handle them all.

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    class Error < StandardError; end
    class RejectedError < Error; end
    class ServiceError < Error; end

    # ...

    def call
      response = NewsletterClient.new.create_newsletter(post)
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

Raise `ServiceError` for the client's base error class, e.g. `NewsletterClient::Error`, not a list of its errors. Then every failure of the service, e.g. a server error, a timeout or a refused connection, reaches the controller's handler. Rescue the causes the user can fix first, because Ruby uses the first `rescue` that matches. An error the action doesn't wrap is a bug, so it fails as normal.

## Transactions

When an action writes more than once, wrap the writes in a transaction, so either they all save or none do. Then the action is safe whoever calls it, and no caller has to remember to wrap it. An action that writes once doesn't need a transaction.

```ruby
def call
  return if post.archived_at?

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

`with_lock` raises an error if the record has unsaved changes, because reloading would throw them away. This is one reason to [never pass a record with unsaved changes](#arguments) to an action. When the action needs new values, set them inside the lock, so the check and the whole update happen together.

You may check the condition before you take the lock, to skip the lock when the work is plainly not needed. Always check it again inside the lock, because another process may have changed the record while you waited for it.

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

Use `next` to leave a `transaction` or `with_lock` block early, never `return`. What a `return` inside the block does has changed between Rails versions, and depends on the app's config: it may commit or roll back. `next` ends the block, and the transaction commits as normal.

When the check fails, decide what the caller needs to know. If the work is already done, e.g. the post is already published, do nothing. The action is then safe to retry, e.g. from a job. If the caller needs to know, e.g. to show a form error, raise the action's `Error`. Do the same thing in the check before the lock and the check inside it, so the result doesn't depend on timing.

When an action locks more than one record, lock them in the same order every time, the parent before its children, e.g. the post before its comments. Two processes that lock in different orders can deadlock.

### Other services

Never call another service inside a transaction. The transaction keeps its locks and its database connection while it waits for the reply. A rollback can't undo the call either. Call the service first, then save its reply in the transaction.

```ruby
def call
  response = NewsletterClient.new.create_newsletter(post)

  ActiveRecord::Base.transaction do
    post.update!(newsletter_id: response.id)
    post.publications.create!(publisher:)
  end
end
```

This includes the caller's transaction. Rails joins a nested `transaction` block to the one around it, so calling the service before the action's own transaction isn't enough. If a form or another action calls this action inside a transaction, the service call is inside it too.

When the action doesn't need the service's reply, don't call the service from the action. Enqueue a job that calls it instead, e.g. `NotifySubscribersJob`. The job waits until the outermost transaction commits, as in [Jobs: Enqueueing after a transaction](../jobs/#enqueueing-after-a-transaction), so it is safe however the action is called.

When a call to another service should be retried if it fails, run it in a job of its own that does nothing else, e.g. `NotifySubscribersJob`. A job retries all of `perform`, so a retry then repeats only that call. The steps before it have already committed, and don't run again.

When a user is waiting for the reply, call the action directly, and don't retry it. The user sees that it failed and can try again, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing).

When the action needs the reply, it must never run inside a transaction. Include a `NonTransactionalCallable` concern, in `app/actions/concerns/non_transactional_callable.rb`. It raises an error when the action is called inside a transaction, so the first caller that wraps it fails in its specs. The transactions that wrap each spec can't be joined, so the check ignores them.

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

### Work after the commit

Some work must wait until the records are committed, e.g. a job that loads them, or a Turbo broadcast that shows them. An action can't do this after its own transaction block, because its caller may still have a transaction open.

For a job, set `enqueue_after_transaction_commit` in the job class, as in [Jobs: Enqueueing after a transaction](../jobs/#enqueueing-after-a-transaction). For any other work, wrap it in `ActiveRecord.after_all_transactions_commit`. The block runs once the outermost transaction commits, never if it rolls back, and at once if no transaction is open.

```ruby
def call
  return if post.archived_at?

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

Never raise `ActiveRecord::Rollback` in an action. In a nested block, Rails swallows it: the block stops, but the caller's transaction carries on and commits. Raise a real error instead, so the whole transaction rolls back.

Rescue errors to raise them again as the action's `Error` outside the transaction block, as in [Error handling](#error-handling). By then the transaction has already rolled back.

### Records that must survive a rollback

Some actions save a fact about what happened, e.g. whether a check passed or failed. That fact must stay saved even when other work fails. Start the name of these actions with `Record`, e.g. `Posts::RecordLinkCheck`, which saves `link_check_status` on the post. The name tells the caller that this write must not roll back with the rest.

Never call a `Record` action inside a transaction. Call it before or after the transaction block. A write inside a transaction rolls back with it, even in a nested block with `requires_new: true`. That only adds a savepoint, which rolls back when the outer transaction does.

```ruby
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
```

The link check commits on its own. If `Posts::ArchivePost` fails, the publish rolls back, but the link check stays saved. When later work depends on the result, read it from the record, e.g. `post.link_check_failed?`.

To record that the transaction itself failed, call the `Record` action in a `rescue` or `ensure` on the caller's method. The transaction has rolled back by then, so the write stays saved.

## Testing

### Action specs

Write an action spec as a unit spec, and name the `describe` block `".call"`, after the method the spec calls. Stub everything the action calls, and check that it calls each one with the right arguments. Avoid creating records, even when the action runs a query. The request and job specs for its callers run the action for real, so its unit spec only checks what the action asks for.

Use `instance_double`, e.g. `instance_double(Post)`, not a plain `double`. See [RSpec: Doubles, build_stubbed or create](../gems/rspec/#doubles-build_stubbed-or-create).

An action does one task, so its unit spec stays short. If the spec needs a lot of stubs to set up, the action is often doing too much. Split it into smaller actions. If a chain of calls is hard to stub, move the chain into a method on the model, so the spec stubs one method. See [Models: Scopes and queries](../models/#scopes-and-queries).

```ruby
RSpec.describe Posts::ArchivePost do
  describe ".call" do
    it "archives the post and locks its comments" do
      travel_to Time.zone.now

      post = instance_double(Post, archived_at?: false)
      comments = instance_double(ActiveRecord::Relation)
      allow(post).to receive(:comments).and_return(comments)

      expect(post).to receive(:update!).with(archived_at: Time.zone.now)
      expect(comments).to receive(:update_all).with(locked: true, updated_at: Time.zone.now)

      described_class.call(post)
    end
  end
end
```

Stub a collaborator to raise an error, to check that the action raises its own `Error` in its place.

```ruby
it "raises an Error when the post is invalid" do
  post = instance_double(Post, archived_at?: false)
  allow(post).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

  expect { described_class.call(post) }.to raise_error(described_class::Error)
end
```

An action that calls another action is a caller too, so the other action is invisible to its spec, as in [Specs for callers](#specs-for-callers). Avoid stubbing it. Let it run on the same doubles, and check the result, e.g. that the post is archived and its comments are locked. You can then change how the other action works, and the spec only fails if the result changes. To check that the action raises its own `Error` in place of the other action's, stub a record method the other action calls to raise.

```ruby
it "archives a published post and locks its comments" do
  travel_to Time.zone.now

  comments = instance_double(ActiveRecord::Relation)
  post = instance_double(Post, archived_at?: false, published?: true, comments:)
  allow(post).to receive(:update!)

  expect(post).to receive(:update!).with(archived_at: Time.zone.now)
  expect(comments).to receive(:update_all).with(locked: true, updated_at: Time.zone.now)

  described_class.call(post)
end
```

When the action writes to a relation, stub the method that returns it, e.g. `post.unlocked_comments` or `Comment.on_posts(posts)`, to return an `instance_double(ActiveRecord::Relation)`. Then expect the write on it. Pass a relation double in as the records, e.g. `posts` for `Posts::ArchivePosts`.

```ruby
RSpec.describe Posts::ArchivePosts do
  describe ".call" do
    it "archives the posts and locks their comments" do
      travel_to Time.zone.now

      posts = instance_double(ActiveRecord::Relation)
      comments = instance_double(ActiveRecord::Relation)
      allow(Comment).to receive(:on_posts).with(posts).and_return(comments)

      expect(comments).to receive(:update_all).with(locked: true, updated_at: Time.zone.now)
      expect(posts).to receive(:update_all).with(archived_at: Time.zone.now, updated_at: Time.zone.now)

      described_class.call(posts)
    end
  end
end
```

When the action loops with `find_each`, stub it to yield doubles, e.g. `allow(posts).to receive(:find_each).and_yield(post)`.

The unit spec checks the action alone. The request and job specs for its callers let it run for real, so between them they check that it works with the rest of the app.

### Specs for callers

Never stub or mock an action in a request spec or a job spec, e.g. with `allow(Posts::ArchivePost).to receive(:call)` or `expect(Posts::ArchivePost).to receive(:call).with(post)`. To these specs, the action is invisible. The same goes for the form that calls it. Let them run, and check what the controller or job does: the records it changes, the response, the flash and the jobs it enqueues.

An action is a detail of how the controller or job does its work. If the spec checks the result, you can move code into an action, or out of it, without changing the spec. A spec that stubs the action only checks that the action was called. It still passes when the action is broken, or when the action is called with the wrong arguments.

```ruby
module Posts
  class ArchivesController < BaseController
    # POST /posts/:post_id/archive
    def create
      # ...

      @archive_post_form = ArchivePostForm.new(@post, current_user)

      if @archive_post_form.submit
        redirect_to posts_path,
          notice: "Post was archived."
      else
        redirect_to post_path(@post),
          alert: "Post could not be archived."
      end
    end
  end
end
```

```ruby
RSpec.describe "Posts::Archives" do
  describe "POST /posts/:post_id/archive", :aggregate_failures do
    # ...

    it "archives the post" do
      published_post = create(:post)
      comment = create(:comment, post: published_post)

      expect {
        post post_archive_path(published_post)
      }.to change { published_post.reload.archived_at }.from(nil)

      expect(comment.reload).to be_locked
      expect(response).to redirect_to(posts_path)
      expect(flash.to_hash).to match("notice" => "Post was archived.")
    end
  end
end
```

To test how a caller handles the action's `Error`, set up records that make the action fail for real. Don't stub the action to raise it, e.g. with `allow(Posts::ArchivePost).to receive(:call).and_raise(Posts::ArchivePost::Error)`.
