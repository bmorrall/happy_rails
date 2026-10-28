---
title: Jobs
parent: Testing
nav_order: 8
---

# Jobs

How I test jobs.

For the code itself, see [Jobs](../../guide/jobs/).

Test a job the way you test a controller with a request spec. Run it with `perform_now`, and check what it does: the records it changes, the emails it sends, the jobs it enqueues and the requests it makes. You MUST NOT stub the models, actions, services or other classes the job calls, e.g. with `allow(NewsletterClient).to receive(:new)` or `allow(Posts::ArchivePost).to receive(:call)`. Then the spec fails when any part of the work breaks, not only the job's own lines. To test how the job handles an action's `Error`, set up records that make the action fail for real. You MUST NOT test the action's argument checks, e.g. `unmodified:`, because every job spec that calls the action already runs them. See [Actions: Specs for callers](../actions/#specs-for-callers).

Name the `describe` block `".perform_now"`, after the method the spec calls, not `"#perform"`.

Stub only the HTTP requests the job makes to other services, and check that it made them. Use the service's stub helpers from `spec/support`, and check the stub each one returns. When a service's SDK has its own stubs, e.g. `stub_responses` in the AWS SDK, use them instead. See [Other Services](../other-services/).

```ruby
class NotifySubscribersJob < ApplicationJob
  # ...

  def perform(post)
    NewsletterClient.new.deliver(post.newsletter_id)
  end
end
```

```ruby
RSpec.describe NotifySubscribersJob do
  describe ".perform_now" do
    it "sends the post to the newsletter service" do
      post = build_stubbed(:post)
      newsletter_request = stub_newsletter_create

      described_class.perform_now(post)

      expect(newsletter_request).to have_been_requested
    end
  end
end
```

## Background jobs

Rails tests `perform_later` itself. Your job adds declarations that change what it does: `queue_as`, `discard_on ActiveJob::DeserializationError` and `enqueue_after_transaction_commit`. In a `describe ".perform_later"` block, test each declaration the job has. Everything the job does when it runs goes in `describe ".perform_now"`, e.g. the requests it makes and the records it changes.

`retry_on`, `rescue_from` and any other `discard_on` act when the job runs, so test them in `.perform_now`. `perform_now` runs the job's error handlers, e.g. a `retry_on` example can check that the job is enqueued again with `have_enqueued_job(described_class).with(post)`.

When the job enqueues other jobs as it runs, check each one in `.perform_now`, with its arguments, as in [RSpec: Enqueued jobs](../gems/rspec/#enqueued-jobs).

You SHOULD NOT check the job's arguments in `.perform_later`. No declaration changes them, and the request spec already checks that the action enqueues the job with them. See [Controllers: Request specs](../controllers/#request-specs).

Build the records with `build_stubbed` when the example doesn't run the job from the queue, e.g. for the queue and the transaction. `perform_later` saves a record as its GlobalID, so it only needs an `id`. See [RSpec: Doubles, build_stubbed or create](../gems/rspec/#doubles-build_stubbed-or-create).

Include `ActiveJob::TestHelper` in job specs, in `spec/support/active_job.rb`, as for [feature specs](#feature-specs).

```ruby
# spec/support/active_job.rb
RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :job
  # ...
end
```

### Queues

Check that the job is enqueued on the queue its `queue_as` names, with `have_enqueued_job(...).on_queue`. See [Jobs: Queues](../../guide/jobs/#queues).

```ruby
RSpec.describe NotifySubscribersJob do
  describe ".perform_later" do
    it "enqueues the job on the default queue" do
      post = build_stubbed(:post)

      expect { described_class.perform_later(post) }.to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
```

When `queue_as` takes a block, write one example for each queue it can pick.

```ruby
RSpec.describe NotifySubscribersJob do
  describe ".perform_later" do
    it "enqueues news posts on the high queue" do
      post = build_stubbed(:post, category: :news)

      expect { described_class.perform_later(post) }.to have_enqueued_job(described_class).on_queue("high")
    end

    it "enqueues other posts on the default queue" do
      post = build_stubbed(:post, category: :opinion)

      expect { described_class.perform_later(post) }.to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
```

### Records deleted before the job runs

When the job has `discard_on ActiveJob::DeserializationError`, enqueue the job, delete the record, then run the queue with `perform_enqueued_jobs`. Check that it doesn't raise and does none of its work. See [Jobs: Records deleted before the job runs](../../guide/jobs/#records-deleted-before-the-job-runs).

Check the work the job would otherwise do, e.g. the request to the newsletter service, so the example fails if the job runs. When the job waits for the commit, check that it was enqueued before you delete the record, so the example can't pass against an empty queue.

Use `create`, not `build_stubbed`, because the example deletes the record and runs the job. A stubbed post was never saved, so the job is discarded even without the delete, and the example passes without testing anything.

You MUST NOT use `perform_now` for this. `perform_now` takes the record as it is, so the spec never loads it from the queue and can't see that it is gone.

```ruby
RSpec.describe NotifySubscribersJob do
  describe ".perform_later" do
    it "is discarded when the post is deleted before it runs", :aggregate_failures do
      post = create(:post)
      newsletter_request = stub_newsletter_create
      described_class.perform_later(post)
      expect(described_class).to have_been_enqueued

      post.destroy!

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(newsletter_request).not_to have_been_requested
    end
  end
end
```

### Enqueueing after a transaction

When the job sets `enqueue_after_transaction_commit`, check that it waits for the transaction to commit, and that it isn't enqueued when the transaction rolls back. See [Jobs: Enqueueing after a transaction](../../guide/jobs/#enqueueing-after-a-transaction).

You SHOULD NOT write either check for a job that enqueues at once, because a rolled-back transaction doesn't remove it from the queue.

```ruby
RSpec.describe NotifySubscribersJob do
  describe ".perform_later" do
    it "waits for the transaction to commit before enqueuing the job", :aggregate_failures do
      post = build_stubbed(:post)

      expect do
        ActiveRecord::Base.transaction do
          described_class.perform_later(post)

          expect(described_class).not_to have_been_enqueued
        end
      end.to have_enqueued_job(described_class)
    end

    it "does not enqueue the job when the transaction rolls back" do
      post = build_stubbed(:post)

      expect do
        ActiveRecord::Base.transaction do
          described_class.perform_later(post)
          raise ActiveRecord::Rollback
        end
      end.not_to have_enqueued_job(described_class)
    end
  end
end
```

### Jobs that run at a set time

When the job has a class method that enqueues it, e.g. `perform_later_for`, test it in a `describe` block named after the method, e.g. `describe ".perform_later_for"`. Check that it enqueues the job for the time it works out, with `have_enqueued_job(...).at`. See [Jobs: Jobs that run at a set time](../../guide/jobs/#jobs-that-run-at-a-set-time).

```ruby
RSpec.describe PublishScheduledPostJob do
  describe ".perform_later_for" do
    it "enqueues the job to run at the post's publish time" do
      publish_at = Time.zone.local(2026, 10, 31, 9, 0)
      post = build_stubbed(:post, publish_at:)

      expect { described_class.perform_later_for(post) }.to have_enqueued_job(described_class).at(publish_at)
    end
  end
end
```

## Scheduling

With all the work for a scheduled task in its job, the job spec covers the whole task. Cover every path through the job, e.g. the drafts it deletes and the posts it keeps. You MUST NOT write a spec for the rake task. It has nothing left to test. See [Jobs: Scheduling](../../guide/jobs/#scheduling).

```ruby
RSpec.describe PurgeAbandonedDraftsJob do
  describe ".perform_now" do
    it "deletes drafts no one has changed for a year" do
      post = create(:post, updated_at: 13.months.ago)

      described_class.perform_now

      expect(Post.exists?(post.id)).to be(false)
    end

    it "keeps drafts changed in the last year" do
      post = create(:post, updated_at: 11.months.ago)

      described_class.perform_now

      expect(Post.exists?(post.id)).to be(true)
    end

    it "keeps published posts" do
      post = create(:post, status: :published, updated_at: 13.months.ago)

      described_class.perform_now

      expect(Post.exists?(post.id)).to be(true)
    end
  end
end
```

## Feature specs

Run every job in at least one feature spec. The job spec checks the job on its own. The feature spec checks that the app enqueues it at the right time, with the right arguments, and that the persona or client gets the result.

Include `ActiveJob::TestHelper` in feature specs, in `spec/support/active_job.rb`. Add a `perform_all_enqueued_jobs` helper there too. Then call it in its own `WHEN` step, after the step that enqueues the job.

You MUST NOT pass `perform_enqueued_jobs` a block in a feature spec. In the app, the request returns before the job runs, so the persona sees the next page without the job's changes. A block runs the job during the request, so the next page already has them. The spec then passes even when the persona would never see the change.

Check for the success message before you call `perform_all_enqueued_jobs`. In a browser, `click_button` can return before the request has finished. Capybara waits for the message to appear, so the job is in the queue when you run it.

After the jobs run, check what the persona sees, and the requests the jobs make to other services. The page only changes when a job updates it, e.g. with a Turbo broadcast. When the scenario checks a change a job makes to a page that it doesn't update, visit the page again, as the persona would reload it.

`perform_enqueued_jobs` only runs the jobs that are in the queue when you call it. A job that enqueues a follow-up job leaves it in the queue. `perform_all_enqueued_jobs` keeps running the queue until no jobs are due, so the scenario doesn't need to know which jobs enqueue others. It fails when no jobs are due to start with, so the step can't pass when the app didn't enqueue the job.

It only runs the jobs that are due now. A job scheduled for later stays in the queue, e.g. `PublishScheduledPostJob` for a post's `publish_at`, or a `retry_on` retry that waits. The persona doesn't see a job's work before it runs, so the scenario doesn't either.

It also fails when jobs are still due after 10 rounds, e.g. a job that keeps enqueueing itself to run at once. A scenario with a longer chain of jobs can raise the limit with `max_rounds:`. You SHOULD NOT raise it to get past the error. That hides a job that keeps enqueueing itself.

```ruby
# spec/support/active_job.rb
module ActiveJobFeatureSpecHelpers
  def perform_all_enqueued_jobs(max_rounds: 10)
    expect(due_enqueued_jobs).not_to be_empty, "expected jobs to be due, but none are"

    max_rounds.times do
      perform_enqueued_jobs(at: Time.zone.now)
      return if due_enqueued_jobs.empty?
    end

    raise "jobs are still due after #{max_rounds} rounds: #{due_enqueued_jobs.map { |job| job[:job] }.uniq.join(", ")}"
  end

  private

  def due_enqueued_jobs
    enqueued_jobs.select { |job| job[:at].nil? || job[:at] <= Time.zone.now.to_f }
  end
end

RSpec.configure do |config|
  # ...
  config.include ActiveJob::TestHelper, type: :feature
  config.include ActiveJobFeatureSpecHelpers, type: :feature
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
    newsletter_request = stub_newsletter_create

    # WHEN I publish the post
    visit post_path(post)
    click_button "Publish"

    # THEN I see that it was published
    expect(page).to have_css(".notice", text: "Post was published.")

    # WHEN the background jobs run
    perform_all_enqueued_jobs

    # THEN the post is sent to the subscribers
    expect(newsletter_request).to have_been_requested
  end
end
```

To run a job scheduled for later, move the clock to its time with `travel_to` in its own `WHEN` step, then call `perform_all_enqueued_jobs`. The step says that time has passed, as the persona would wait for it.

```ruby
RSpec.feature "Post Scheduling" do
  scenario "Publishing Manager schedules a post" do
    travel_to Time.zone.local(2026, 11, 2, 9, 0)

    # GIVEN I am signed in as a Publishing Manager
    sign_in create(:user, :publishing_manager)

    # AND there is a draft post
    post = create(:post, title: "Hello World")

    # AND the newsletter service accepts the post
    newsletter_request = stub_newsletter_create

    # WHEN I schedule the post for the next morning
    visit post_path(post)
    fill_in "Publish at", with: Time.zone.local(2026, 11, 3, 9, 0)
    click_button "Schedule"

    # THEN I see that it was scheduled
    expect(page).to have_css(".notice", text: "Post was scheduled.")

    # WHEN it is the post's publish time
    travel_to Time.zone.local(2026, 11, 3, 9, 0)
    perform_all_enqueued_jobs

    # THEN the post is sent to the subscribers
    expect(newsletter_request).to have_been_requested
  end
end
```

A scheduled or maintenance job still needs a feature spec, even though no persona enqueues it. Name the feature after the task, and start the scenario name with the persona who sees the result. Set up the records in the `GIVEN` steps, run the job with `perform_now` in a `WHEN` step, then check what the persona sees. When the job enqueues other jobs, call `perform_all_enqueued_jobs` after it, in its own step.

```ruby
RSpec.feature "Draft Cleanup" do
  scenario "Author no longer sees abandoned drafts" do
    # GIVEN I am signed in as an Author
    author = create(:user)
    sign_in author

    # AND I have a draft I haven't changed for a year
    draft = create(:post, author: author, updated_at: 1.year.ago)

    # WHEN the draft cleanup runs
    PurgeAbandonedDraftsJob.perform_now

    # AND I visit the posts page
    visit posts_path

    # THEN I don't see the abandoned draft
    expect(page).not_to have_link(draft.title)
  end
end
```

When no persona sees the result, e.g. in an app with no users, start the scenario name with the client that does, as for an API, e.g. `scenario "API client no longer gets abandoned drafts"`. Write the steps as that client, and check what it gets back from the API, or the request the job makes to another service. See [RSpec: API endpoints](../gems/rspec/#api-endpoints).

```ruby
RSpec.feature "Draft Cleanup" do
  scenario "API client no longer gets abandoned drafts" do
    # GIVEN I have an access token
    client = ActionDispatch::Integration::Session.new(Rails.application)
    headers = { "Authorization" => "Bearer #{Rails.application.credentials.api_token}" }

    # AND there is a draft no one has changed for a year
    draft = create(:post, updated_at: 1.year.ago)

    # WHEN the draft cleanup runs
    PurgeAbandonedDraftsJob.perform_now

    # AND I fetch the posts
    client.get api_v1_posts_path, headers: headers

    # THEN I don't get the abandoned draft
    expect(client.response).to have_http_status(:ok)
    expect(client.response.parsed_body).not_to include(a_hash_including("id" => draft.id))
  end
end
```
