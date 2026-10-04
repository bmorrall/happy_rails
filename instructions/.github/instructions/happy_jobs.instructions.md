---
applyTo: "app/jobs/**/*.rb,spec/jobs/**/*.rb"
---

# Jobs

- Write background jobs with Active Job. Inherit from `ApplicationJob` and enqueue with `perform_later`, e.g. `NotifySubscribersJob.perform_later(post)`.
- Enqueue a job only after the transactions that change its arguments have committed. Set `self.enqueue_after_transaction_commit = true` in the job class, e.g. in `NotifySubscribersJob`.
- If you can't change the job class, e.g. it comes from a gem, wrap the enqueue in an `ActiveRecord.after_all_transactions_commit` block, e.g. `ActiveRecord.after_all_transactions_commit { NotifySubscribersJob.perform_later(post) }`.
- Test a job like a request spec: run it with `perform_now` and check its effects, e.g. the records it changes, the emails it sends, the jobs it enqueues and the requests it makes. Never stub the models, services or other classes the job calls, e.g. `allow(NewsletterClient).to receive(:new)`.
- In job specs, name the `describe` block after the method the spec calls, e.g. `describe ".perform_now"`, not `describe "#perform"`.
- In job specs, stub only the HTTP requests the job makes to other services, and assert that it made them, e.g. `newsletter_request = stub_request(:post, "https://newsletter.example.com/posts")` then `expect(newsletter_request).to have_been_requested`.
- Run every job in at least one feature spec, so the spec checks that the app enqueues it and the persona gets the result.
- Include `ActiveJob::TestHelper` in feature specs in `spec/support/active_job.rb`, e.g. `config.include ActiveJob::TestHelper, type: :feature`. Wrap the step that enqueues a job in `perform_enqueued_jobs`, and check for the success message inside the block, so the block waits for the request to finish and runs any jobs those jobs enqueue, e.g. `perform_enqueued_jobs { click_button "Publish"; expect(page).to have_css(".notice", text: "Post was published.") }`.
- Write a feature spec for every scheduled or maintenance job too. Name the feature after the task and start the scenario name with the persona who sees the result, e.g. `RSpec.feature "Draft Cleanup"` with `scenario "Author no longer sees abandoned drafts"`. Run the job with `perform_now` inside `perform_enqueued_jobs` in a `# WHEN` step, so any jobs it enqueues also run, e.g. `# WHEN the draft cleanup runs` then `perform_enqueued_jobs { PurgeAbandonedDraftsJob.perform_now }`, then check what the persona sees.
- TODO: How to schedule recurring jobs.
