---
title: Side Effects of Saving
parent: Patterns
nav_order: 4
---

# Side Effects of Saving

Saving a record often means more work: other records change, a job is enqueued, or another service is called. A callback looks like the easy place for it, but a callback only changes the record's own attributes. See [Models: Callbacks](../../guide/models/#callbacks).

```ruby
# Don't do this
class Post < ApplicationRecord
  after_update_commit :lock_comments,
    if: :archived?

  after_update_commit :notify_subscribers,
    if: :published?
end
```

Put the work in the code that does the task instead. Each solution below fits a different kind of side effect. They all leave the model to save itself, and show the rest of the work in the caller.

## In the form

When only one place does the task, do the side effects in the form's `submit`. Save the records in a transaction, so they all save or none do. Then enqueue jobs and send emails after the transaction, so they only run for records that were committed. See [Forms: Saving several records](../../guide/forms/#saving-several-records).

```ruby
class PublishPostForm < ApplicationForm
  # ...

  ### Public Methods ###

  def submit
    return false unless valid?

    ActiveRecord::Base.transaction do
      post.update!(status: :published)
      post.publications.create!(publisher: current_user)
    end

    NotifySubscribersJob.perform_later(post)
    post
  rescue ActiveRecord::RecordInvalid => e
    merge_errors_from(e.record)
    false
  end
end
```

## In an action

When other records must change with the record every time, wherever the task is run from, put the changes in an action. Every caller gets them, and none can forget them. Archiving a post always locks its comments, so `Posts::ArchivePost` does both in one transaction. See [Actions: Transactions](../../guide/actions/#transactions).

```ruby
module Posts
  class ArchivePost < ApplicationAction
    # ...

    def call
      ActiveRecord::Base.transaction do
        post.update!(archived_at: Time.current)
        post.comments.update_all(locked: true)
      end
    end
  end
end
```

Keep jobs and emails in the caller, after the action returns, unless every caller needs them too. When the action does them, remember that its caller may have a transaction open around it. Set `self.enqueue_after_transaction_commit = true` in the job class, and wrap other work in `ActiveRecord.after_all_transactions_commit`. See [Actions: Work after the commit](../../guide/actions/#work-after-the-commit).

## In a job

When the side effect calls another service, run it in a job. The call is slow and can fail, and a job runs it on its own, with retries. The record is saved either way, so a failing service never stops the user's change. `NotifySubscribersJob` sends a published post to the newsletter service.

```ruby
class NotifySubscribersJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  def perform(post)
    NewsletterClient.new.deliver(post)
  end
end
```

When the task needs the service's reply before it can save, call the service from the action instead, before its transaction. Include `NonTransactionalCallable` in the action, so no caller can run it inside a transaction. See [Actions: Other services](../../guide/actions/#other-services).

## In several steps

When the side effects form a process, e.g. check the links, then publish, then notify subscribers, run each step from a job. Each step then commits and retries on its own. See [Multi-Step Processes](../multi-step-processes/).
