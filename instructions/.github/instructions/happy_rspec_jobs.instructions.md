---
applyTo: "spec/jobs/**/*.rb,spec/features/**/*.rb"
---

# Job specs

- Test a job like a request spec: run it with `perform_now` and check its effects, e.g. the records it changes, the emails it sends, the jobs it enqueues and the requests it makes. You MUST NOT stub the models, actions, services or other classes the job calls, e.g. `allow(NewsletterClient).to receive(:new)` or `allow(Posts::ArchivePost).to receive(:call)`. To test how the job handles an action's `Error`, set up records that make the action fail for real.
- In job specs, you MUST NOT test an action's argument checks, e.g. that `Posts::PublishPost` raises `ActiveModel::ValidationError` for a post with unsaved changes from `unmodified:`.
- In job specs, name the `describe` block after the method the spec calls, e.g. `describe ".perform_now"`, not `describe "#perform"`.
- In job specs, stub only the HTTP requests the job makes to other services, and assert that it made them, with the service's stub helpers from `spec/support`, e.g. `newsletter_request = stub_newsletter_create` then `expect(newsletter_request).to have_been_requested`. When a service's SDK has its own stubs, use them instead, e.g. `stub_responses` in the AWS SDK.
- Cover every path through a scheduled job in its job spec, e.g. the drafts `PurgeAbandonedDraftsJob` deletes and the posts it keeps. You MUST NOT write a spec for the rake task.
- When a job has `discard_on ActiveJob::DeserializationError`, test it with `perform_later` in a `describe ".perform_later"` block: enqueue the job, delete the record, then run it with `perform_enqueued_jobs`, and check that it doesn't raise and does none of its work, e.g. `described_class.perform_later(post)`, `post.destroy`, `expect { perform_enqueued_jobs }.not_to raise_error` and `expect(newsletter_request).not_to have_been_requested`. You MUST NOT use `perform_now` for this.
- Run every job in at least one feature spec, so the spec checks that the app enqueues it and the persona gets the result.
- In feature specs, wrap the step that enqueues a job in `perform_enqueued_jobs`, and check for the success message inside the block, so the block waits for the request to finish and runs any jobs those jobs enqueue, e.g. `perform_enqueued_jobs { click_button "Publish"; expect(page).to have_css(".notice", text: "Post was published.") }`.
- Write a feature spec for every scheduled or maintenance job too. Name the feature after the task and start the scenario name with the persona who sees the result, e.g. `RSpec.feature "Draft Cleanup"` with `scenario "Author no longer sees abandoned drafts"`. Run the job with `perform_now` inside `perform_enqueued_jobs` in a `# WHEN` step, so any jobs it enqueues also run, e.g. `# WHEN the draft cleanup runs` then `perform_enqueued_jobs { PurgeAbandonedDraftsJob.perform_now }`, then check what the persona sees.
