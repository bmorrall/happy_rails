---
title: Jobs
parent: Testing
nav_order: 8
---

# Jobs

How I test jobs.

For the code itself, see [Jobs](../../guide/jobs/).

## Scheduling

With all the work for a scheduled task in its job, the [job spec](#job-specs) covers the whole task. Cover every path through the job, e.g. the drafts it deletes and the posts it keeps. Don't write a spec for the rake task. It has nothing left to test. See [Jobs: Scheduling](../../guide/jobs/#scheduling).

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

## Job specs

Test a job the way you test a controller with a request spec. Run it with `perform_now`, and check what it does: the records it changes, the emails it sends, the jobs it enqueues and the requests it makes. Don't stub the models, actions, services or other classes the job calls, e.g. with `allow(NewsletterClient).to receive(:new)` or `allow(Posts::ArchivePost).to receive(:call)`. Then the spec fails when any part of the work breaks, not only the job's own lines. To test how the job handles an action's `Error`, set up records that make the action fail for real. Don't test the action's argument checks, e.g. `unmodified:`, because every job spec that calls the action already runs them. See [Actions: Specs for callers](../actions/#specs-for-callers).

Name the `describe` block `".perform_now"`, after the method the spec calls, not `"#perform"`.

Stub only the HTTP requests the job makes to other services, and check that it made them. Use the service's stub helpers from `spec/support`, and check the stub each one returns. When a service's SDK has its own stubs, e.g. `stub_responses` in the AWS SDK, use them instead. See [WebMock and VCR](../gems/webmock/).

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
      post = create(:post)
      newsletter_request = stub_newsletter_create

      described_class.perform_now(post)

      expect(newsletter_request).to have_been_requested
    end
  end
end
```

## Deleted records

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
      newsletter_request = stub_newsletter_create

      described_class.perform_later(post)
      post.destroy

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(newsletter_request).not_to have_been_requested
    end
  end
end
```

## Feature specs

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
    newsletter_request = stub_newsletter_create

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
