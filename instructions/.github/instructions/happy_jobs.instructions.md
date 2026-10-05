---
applyTo: "app/jobs/**/*.rb,spec/jobs/**/*.rb"
---

# Jobs

- Write background jobs with Active Job. Inherit from `ApplicationJob` and enqueue with `perform_later`, e.g. `NotifySubscribersJob.perform_later(post)`.
- Pass records to a job, never their IDs, e.g. `NotifySubscribersJob.perform_later(post)`, not `NotifySubscribersJob.perform_later(post.id)`. Never call `find` in `perform` to load a record from an ID argument.
- When a job's record could reasonably be deleted before the job runs, add `discard_on ActiveJob::DeserializationError` to that job, e.g. in `NotifySubscribersJob`. Never rescue the missing record in `perform`, because Active Job loads the record before `perform` runs.
- Never add `discard_on ActiveJob::DeserializationError` to `ApplicationJob`. Add it only to the jobs whose records may be gone.
- Enqueue a job only after the transactions that change its arguments have committed. Set `self.enqueue_after_transaction_commit = true` in the job class, e.g. in `NotifySubscribersJob`.
- If you can't change the job class, e.g. it comes from a gem, wrap the enqueue in an `ActiveRecord.after_all_transactions_commit` block, e.g. `ActiveRecord.after_all_transactions_commit { NotifySubscribersJob.perform_later(post) }`.
- When the work in `perform` could be run from somewhere else too, e.g. a form or the console, put it in an action and call it from `perform`, e.g. `Posts::PublishPost.call(post, publisher: post.scheduled_by)` in `PublishScheduledPostJob`. Keep work that only the job does in `perform`.
- Pass an action the records and values it needs. When it needs a user, take the user from a record or the job's arguments and pass it under its role, e.g. `publisher: post.scheduled_by`. Never look for a signed-in user in a job.
- When an action's `Error` is an outcome the app expects, rescue it in `perform` and save it on the record the job works on, e.g. `rescue Posts::PublishPost::Error` then `post.update!(publish_status: :failed)`. Let any other error pass through, so the job fails and can retry.
- Make every action a job calls safe to run again, because the job may retry, e.g. `Posts::PublishPost` does nothing if the post is already published.
- When a job runs at a set time with `wait_until` and a user can change or cancel that time, check that the work is still due at the start of `perform`, and return if it isn't, e.g. `return unless post.publish_at&.past?` in `PublishScheduledPostJob`.
- Open a transaction in `perform` only to combine several actions into one unit. Don't wrap a single action in a transaction. Call a `Record` action before or after the transaction block, never inside it.
- Test a job like a request spec: run it with `perform_now` and check its effects, e.g. the records it changes, the emails it sends, the jobs it enqueues and the requests it makes. Never stub the models, actions, services or other classes the job calls, e.g. `allow(NewsletterClient).to receive(:new)` or `allow(Posts::ArchivePost).to receive(:call)`.
- In job specs, name the `describe` block after the method the spec calls, e.g. `describe ".perform_now"`, not `describe "#perform"`.
- In job specs, stub only the HTTP requests the job makes to other services, and assert that it made them, e.g. `newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")` then `expect(newsletter_request).to have_been_requested`.
- When a job has `discard_on ActiveJob::DeserializationError`, test it with `perform_later` in a `describe ".perform_later"` block: enqueue the job, delete the record, then run it with `perform_enqueued_jobs`, and check that it doesn't raise and does none of its work, e.g. `described_class.perform_later(post)`, `post.destroy`, `expect { perform_enqueued_jobs }.not_to raise_error` and `expect(newsletter_request).not_to have_been_requested`. Never use `perform_now` for this, because it never loads the record again.
- Include `ActiveJob::TestHelper` in job specs in `spec/support/active_job.rb`, e.g. `config.include ActiveJob::TestHelper, type: :job`.
- Run every job in at least one feature spec, so the spec checks that the app enqueues it and the persona gets the result.
- Include `ActiveJob::TestHelper` in feature specs in `spec/support/active_job.rb`, e.g. `config.include ActiveJob::TestHelper, type: :feature`. Wrap the step that enqueues a job in `perform_enqueued_jobs`, and check for the success message inside the block, so the block waits for the request to finish and runs any jobs those jobs enqueue, e.g. `perform_enqueued_jobs { click_button "Publish"; expect(page).to have_css(".notice", text: "Post was published.") }`.
- Write a feature spec for every scheduled or maintenance job too. Name the feature after the task and start the scenario name with the persona who sees the result, e.g. `RSpec.feature "Draft Cleanup"` with `scenario "Author no longer sees abandoned drafts"`. Run the job with `perform_now` inside `perform_enqueued_jobs` in a `# WHEN` step, so any jobs it enqueues also run, e.g. `# WHEN the draft cleanup runs` then `perform_enqueued_jobs { PurgeAbandonedDraftsJob.perform_now }`, then check what the persona sees.
- TODO: How to schedule recurring jobs.
