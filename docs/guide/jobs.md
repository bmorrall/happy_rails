---
title: Jobs
parent: The Guide
nav_order: 8
---

# Jobs

Background work.

## Background jobs

Write background jobs with Active Job. Each job inherits from `ApplicationJob`, and the code that needs it calls `perform_later`. Active Job keeps the jobs separate from the queue backend, so you can change the backend without rewriting the jobs.

```ruby
class NotifySubscribersJob < ApplicationJob
  def perform(post)
    # ...
  end
end
```

Pass the record to the job, not its ID, e.g. `NotifySubscribersJob.perform_later(post)`, not `NotifySubscribersJob.perform_later(post.id)`. Active Job saves the record as a GlobalID and loads it again when the job runs, so the job always sees the current values. The job doesn't need its own `find`, and its arguments say which kind of record it takes.

```ruby
NotifySubscribersJob.perform_later(post)
```

### Queues

Every job SHOULD name its queue with `queue_as`, even when it uses the default queue. The name shows that someone chose the queue. You can then give a queue its own workers, or run it at a higher priority, without changing the job.

```ruby
class NotifySubscribersJob < ApplicationJob
  queue_as :default

  # ...
end
```

Each job SHOULD use one of these queues, from the highest priority to the lowest:

- `high`: jobs that have to run on time, e.g. `PublishScheduledPostJob`.
- `default`: most jobs, e.g. `NotifySubscribersJob`.
- `mailers`: emails sent with `deliver_later`.
- `low`: jobs that can wait, e.g. `PurgeAbandonedDraftsJob`.

These are a starting point. Add a queue when a group of jobs needs its own workers or its own priority.

When the queue depends on the job's arguments, pass `queue_as` a block, and read the arguments with `arguments`. The job then picks the queue for every caller. See [Actions: Calling other actions](../actions/#calling-other-actions) for why callers leave the queue to the job.

```ruby
class NotifySubscribersJob < ApplicationJob
  queue_as do
    post = arguments.first
    post.news? ? :high : :default
  end

  # ...
end
```

Rails puts emails sent with `deliver_later` on the `default` queue. Set `deliver_later_queue_name` in `config/application.rb` to move them to the `mailers` queue.

```ruby
# config/application.rb
config.action_mailer.deliver_later_queue_name = :mailers
```

### Records deleted before the job runs

If the record is deleted before the job runs, Active Job can't load it, and raises `ActiveJob::DeserializationError`. It raises the error before `perform` runs, so a `rescue` in `perform` doesn't catch it. When the record could reasonably be gone by then, e.g. a user can delete a post before its subscribers are notified, add `discard_on ActiveJob::DeserializationError` to that job. The job then stops quietly, because there is no work left to do.

```ruby
class NotifySubscribersJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  # ...
end
```

Add it only to the jobs that need it, not to `ApplicationJob`. In any other job, a missing record is a bug, and the error needs to be reported.

### Enqueueing after a transaction

Enqueue a job only after the transactions that change its arguments have committed. Active Job passes a record to the job by its ID, and the job loads it again when it runs. A job enqueued inside a transaction could run before the transaction commits. It would not find a new record, or it would see the old values. If the transaction rolls back, the job runs for changes that never happened.

Set `enqueue_after_transaction_commit` in the job class. `perform_later` then waits until the open transactions commit, and drops the job if one rolls back. If no transaction is open, it enqueues the job at once. Callers can then enqueue the job from anywhere, e.g. an action or a form, and don't have to think about transactions.

```ruby
class NotifySubscribersJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  def perform(post)
    # ...
  end
end
```

If you can't change the job class, e.g. it comes from a gem, wrap the enqueue in an `ActiveRecord.after_all_transactions_commit` block instead. The block works the same way: it runs after the open transactions commit, never if one rolls back, and at once if no transaction is open.

```ruby
ActiveRecord.after_all_transactions_commit do
  NotifySubscribersJob.perform_later(post)
end
```

### Calling actions

A job is a caller, like a form. When the work in `perform` could be run from somewhere else too, e.g. a form or the console, put it in an [action](../actions/) and call the action from `perform`. Keep work that only the job does in `perform`. See [Actions: When to write an action](../actions/#when-to-write-an-action).

Pass the action the records and values it needs. A job has no signed-in user, so when the action needs a user, take it from a record or from the job's arguments, and pass it under its role, e.g. `publisher: post.scheduled_by`. See [Principles: The signed-in user](../principles/#the-signed-in-user).

When the action's `Error` is an outcome the app expects, rescue it in `perform` and save it on the record the job works on, e.g. mark the post as failed. Let any other error pass through, so the job fails and can retry.

```ruby
class PublishScheduledPostJob < ApplicationJob
  def perform(post)
    Posts::PublishPost.call(post, publisher: post.scheduled_by)
  rescue Posts::PublishPost::Error
    post.update!(publish_status: :failed)
  end
end
```

A job might run more than once, e.g. when it retries. Write the action so a second run is safe, e.g. it does nothing if the post is already published. See [Actions: Locks](../actions/#locks).

A job that calls another service does only that, so a retry repeats only the call. Run the steps before it in another job, or in the caller. See [Actions: Other services](../actions/#other-services).

An action that writes more than once has its own transaction. Open a transaction in `perform` only to combine several actions into one unit. You SHOULD open it on the model, e.g. `Post.transaction`, not `ActiveRecord::Base.transaction`. Call any `Record` action before or after that transaction, not inside it. To record that the transaction failed, call the `Record` action in a `rescue` or `ensure` on `perform`. See [Actions: Transactions](../actions/#transactions).

### Jobs that run at a set time

When the job works out its enqueue settings from its arguments, e.g. `wait_until: post.publish_at`, put them in a class method on the job, e.g. `perform_later_for`. Its name SHOULD start with `perform_later_`, so callers can see that it enqueues the job and doesn't run it. Callers call the class method, not `set(...).perform_later`. Every caller then enqueues the job the same way, and a caller's spec stubs one method, not a chain.

```ruby
class PublishScheduledPostJob < ApplicationJob
  def self.perform_later_for(post)
    set(wait_until: post.publish_at).perform_later(post)
  end

  # ...
end
```

```ruby
PublishScheduledPostJob.perform_later_for(post)
```

A `perform_later_` method takes the same arguments as the job. You SHOULD NOT give a job one that takes other records and works out the job's arguments from them, e.g. `RefreshNewsletterStatsJob.perform_later_for(post)` for a job that takes a newsletter ID. That ties a job that knows nothing about posts to `Post`. Put that work in an `Enqueue` action instead, e.g. `Posts::EnqueueStatsRefresh`. See [Actions: Calling other actions](../actions/#calling-other-actions).

A job enqueued with `wait_until` runs at that time, even if the record has changed since. When a user can change or cancel the time, e.g. reschedule a post, check that the work is still due at the start of `perform`. If it isn't, return and do nothing. The job enqueued for the new time does the work.

```ruby
class PublishScheduledPostJob < ApplicationJob
  def perform(post)
    return unless post.publish_at&.past?

    Posts::PublishPost.call(post, publisher: post.scheduled_by)
  rescue Posts::PublishPost::Error
    post.update!(publish_status: :failed)
  end
end
```

## Scheduling

When a scheduler outside the app runs a task, e.g. cron or Heroku Scheduler calling a rake task, write the task as a job. Keep the rake task as simple as it can be: one line that runs the job. Put no queries, loops or conditions in it.

```ruby
class PurgeAbandonedDraftsJob < ApplicationJob
  def perform
    Post.draft.where(updated_at: ...1.year.ago).find_each(&:destroy!)
  end
end
```

```ruby
# lib/tasks/posts.rake
namespace :posts do
  desc "Delete drafts no one has changed for a year"
  task purge_abandoned_drafts: :environment do
    PurgeAbandonedDraftsJob.perform_later
  end
end
```

A rake task is hard to test, but a job is easy to test. With all the work in the job, the [job spec](../../testing/jobs/) covers the whole task. The job can also run from the console, and moves to another scheduler without a rewrite. See [Testing: Jobs](../../testing/jobs/#scheduling).

Call `perform_later` in the rake task by default. The task ends as soon as the job is enqueued, and the queue retries the job and reports its errors, like any other job. Call `perform_now` when the scheduler needs to run the work itself, e.g. when no queue worker is running at that time, or the scheduler needs to know whether the task failed.

```ruby
task purge_abandoned_drafts: :environment do
  PurgeAbandonedDraftsJob.perform_now
end
```

## Testing

See [Testing: Jobs](../../testing/jobs/).
