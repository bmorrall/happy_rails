---
applyTo: "app/jobs/**/*.rb,lib/tasks/**/*.rake"
---

# Jobs

- Write background jobs with Active Job. Inherit from `ApplicationJob` and enqueue with `perform_later`, e.g. `NotifySubscribersJob.perform_later(post)`.
- Pass records to a job, not their IDs, e.g. `NotifySubscribersJob.perform_later(post)`, not `NotifySubscribersJob.perform_later(post.id)`. You MUST NOT call `find` in `perform` to load a record from an ID argument.
- When a job's record could reasonably be deleted before the job runs, add `discard_on ActiveJob::DeserializationError` to that job, e.g. in `NotifySubscribersJob`. You MUST NOT rescue the missing record in `perform`.
- You MUST NOT add `discard_on ActiveJob::DeserializationError` to `ApplicationJob`. Add it only to the jobs whose records might be gone.
- Enqueue a job only after the transactions that change its arguments have committed. Set `self.enqueue_after_transaction_commit = true` in the job class, e.g. in `NotifySubscribersJob`.
- If you can't change the job class, e.g. it comes from a gem, wrap the enqueue in an `ActiveRecord.after_all_transactions_commit` block, e.g. `ActiveRecord.after_all_transactions_commit { NotifySubscribersJob.perform_later(post) }`.
- When the work in `perform` could be run from somewhere else too, e.g. a form or the console, put it in an action and call it from `perform`, e.g. `Posts::PublishPost.call(post, publisher: post.scheduled_by)` in `PublishScheduledPostJob`. Keep work that only the job does in `perform`.
- When an action's `Error` is an outcome the app expects, rescue it in `perform` and save it on the record the job works on, e.g. `rescue Posts::PublishPost::Error` then `post.update!(publish_status: :failed)`. Let any other error pass through, so the job fails and can retry.
- Keep a job that calls another service to that one call, e.g. `NotifySubscribersJob` only sends the post to the newsletter service. Run any steps before it in another job or in the caller, so a retry repeats only the call.
- Make every action a job calls safe to run again, e.g. `Posts::PublishPost` does nothing if the post is already published.
- When a job runs at a set time with `wait_until` and a user can change or cancel that time, check that the work is still due at the start of `perform`, and return if it isn't, e.g. `return unless post.publish_at&.past?` in `PublishScheduledPostJob`.
- Open a transaction in `perform` only to combine several actions into one unit. You MUST NOT wrap a single action in a transaction. Call a `Record` action before or after the transaction block, not inside it. To record that the transaction failed, call it in a `rescue` or `ensure` on `perform`.
- When a scheduler outside the app runs a task, e.g. cron calling a rake task, write the task as a job, e.g. `PurgeAbandonedDraftsJob`. Keep the rake task to one line that runs the job, e.g. `task purge_abandoned_drafts: :environment do PurgeAbandonedDraftsJob.perform_later end`. You MUST NOT put queries, loops or conditions in the rake task.
- Call `perform_later` in a rake task by default. Call `perform_now` only when the scheduler needs to run the work itself, e.g. when no queue worker is running at that time, or the scheduler needs to know whether the task failed.
