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

Pass the record to the job, never its ID, e.g. `NotifySubscribersJob.perform_later(post)`, not `NotifySubscribersJob.perform_later(post.id)`. Active Job saves the record as a GlobalID and loads it again when the job runs, so the job always sees the current values. The job doesn't need its own `find`, and its arguments say which kind of record it takes.

```ruby
NotifySubscribersJob.perform_later(post)
```

### Records deleted before the job runs

If the record is deleted before the job runs, Active Job can't load it, and raises `ActiveJob::DeserializationError`. It raises the error before `perform` runs, so a `rescue` in `perform` doesn't catch it. When the record could reasonably be gone by then, e.g. a user can delete a post before its subscribers are notified, add `discard_on ActiveJob::DeserializationError` to that job. The job then stops quietly, because there is no work left to do.

```ruby
class NotifySubscribersJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  # ...
end
```

Add it only to the jobs that need it, not to `ApplicationJob`. In any other job, a missing record is a bug, and the error should be reported.

### Enqueueing after a transaction

Enqueue a job only after the transactions that change its arguments have committed. Active Job passes a record to the job by its ID, and the job loads it again when it runs. A job enqueued inside a transaction could run before the transaction commits. It would not find a new record, or it would see the old values. If the transaction rolls back, the job runs for changes that never happened.

Set `enqueue_after_transaction_commit` in the job class. `perform_later` then waits until the open transactions commit, and drops the job if one rolls back. If no transaction is open, it enqueues the job at once. Callers can then enqueue the job from anywhere, e.g. a callback or a form, and don't have to think about transactions.

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

A job may run more than once, e.g. when it retries. Write the action so a second run is safe, e.g. it does nothing if the post is already published. See [Actions: Locks](../actions/#locks).

An action that writes more than once has its own transaction. Open a transaction in `perform` only to combine several actions into one unit. Call any `Record` action before or after that transaction, never inside it. See [Actions: Transactions](../actions/#transactions).

### Jobs that run at a set time

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

> **TODO:** Describe how you handle this.

## Testing

### Job specs

Test a job the way you test a controller with a request spec. Run it with `perform_now`, and check what it does: the records it changes, the emails it sends, the jobs it enqueues and the requests it makes. Don't stub the models, actions, services or other classes the job calls, e.g. with `allow(NewsletterClient).to receive(:new)` or `allow(Posts::ArchivePost).to receive(:call)`. Then the spec fails when any part of the work breaks, not only the job's own lines. See [Actions: Specs for callers](../actions/#specs-for-callers).

Name the `describe` block `".perform_now"`, after the method the spec calls, not `"#perform"`.

Stub only the HTTP requests the job makes to other services, and check that it made them. See [WebMock and VCR](../gems/webmock/).

```ruby
class NotifySubscribersJob < ApplicationJob
  # ...

  def perform(post)
    NewsletterClient.new.deliver(post)
  end
end
```

```ruby
RSpec.describe NotifySubscribersJob do
  describe ".perform_now" do
    it "sends the post to the newsletter service" do
      post = create(:post, title: "Hello World")
      newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")
        .with(body: hash_including(title: "Hello World"))

      described_class.perform_now(post)

      expect(newsletter_request).to have_been_requested
    end
  end
end
```

### Deleted records

When a job discards a missing record, test it with `perform_later`, not `perform_now`. `perform_now` takes the record as it is, so the spec never loads it again and can't see that it is gone. Enqueue the job, delete the record, then run the job with `perform_enqueued_jobs`. Check that it doesn't raise and does none of its work. Name the `describe` block `".perform_later"`, after the method the spec calls.

Include `ActiveJob::TestHelper` in job specs for `perform_enqueued_jobs`, in `spec/support/active_job.rb`, as for [feature specs](#feature-specs).

```ruby
# spec/support/active_job.rb
RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :job
  # ...
end
```

```ruby
RSpec.describe NotifySubscribersJob do
  # ...

  describe ".perform_later" do
    it "does nothing when the post was deleted" do
      post = create(:post)
      newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")

      described_class.perform_later(post)
      post.destroy

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(newsletter_request).not_to have_been_requested
    end
  end
end
```

### Feature specs

Run every job in at least one feature spec. The job spec checks the job on its own. The feature spec checks that the app enqueues it at the right time, with the right arguments, and that the persona gets the result.

Include `ActiveJob::TestHelper` in feature specs, in `spec/support/active_job.rb`. Then wrap the step that enqueues the job in `perform_enqueued_jobs`, so the job runs before the next step.

Put the check for the success message inside the block too, after the click. In a browser, `click_button` can return before the request has finished. Capybara waits for the message to appear, so the block doesn't end before the job is enqueued.

The block also runs any jobs that a job enqueues, as long as they are enqueued before the block ends. A job that enqueues a follow-up job is then covered too.

```ruby
# spec/support/active_job.rb
RSpec.configure do |config|
  # ...
  config.include ActiveJob::TestHelper, type: :feature
end
```

```ruby
RSpec.feature "Post Publishing" do
  scenario "Publishing Manager publishes a post" do
    # GIVEN I am signed in as a Publishing Manager
    sign_in create(:user, :publishing_manager)

    # AND there is a draft post
    post = create(:post, title: "Hello World")

    # AND the newsletter service accepts the post
    newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")

    # WHEN I publish the post
    visit post_path(post)
    perform_enqueued_jobs do
      click_button "Publish"

      # THEN I see that it was published
      expect(page).to have_css(".notice", text: "Post was published.")
    end

    # AND the post is sent to the subscribers
    expect(newsletter_request).to have_been_requested
  end
end
```

A scheduled or maintenance job still needs a feature spec, even though no persona enqueues it. Name the feature after the task, and start the scenario name with the persona who sees the result. Set up the records in the `GIVEN` steps, run the job with `perform_now` in a `WHEN` step, then check what the persona sees. Wrap `perform_now` in `perform_enqueued_jobs` too, so any jobs the task enqueues also run.

```ruby
RSpec.feature "Draft Cleanup" do
  scenario "Author no longer sees abandoned drafts" do
    # GIVEN I am signed in as an Author
    author = create(:user)
    sign_in author

    # AND I have a draft I haven't changed for a year
    create(:post, author: author, title: "Old Idea", updated_at: 1.year.ago)

    # WHEN the draft cleanup runs
    perform_enqueued_jobs do
      PurgeAbandonedDraftsJob.perform_now
    end

    # AND I visit the posts page
    visit posts_path

    # THEN I don't see the abandoned draft
    expect(page).not_to have_link("Old Idea")
  end
end
```
