---
title: Multi-Step Processes
parent: Patterns
nav_order: 3
---

# Multi-Step Processes

How to share a process of several steps between forms and jobs.

Sometimes several callers run the same steps in the same order. For example, a form and a job both publish a post: check its links, publish it, then notify its subscribers. Writing the steps out in each caller lets the copies drift apart. But [an action does one task](../../guide/actions/#calling-other-actions), and should rarely call other actions.

These patterns share the steps within those rules. Pick one with the questions in [Choosing a pattern](#choosing-a-pattern).

## One action with private methods

Often the steps are one task with several parts. If no caller ever wants only some of the steps, write one action, and give each step a private method. "One task" is about what the caller wants done, not how many lines it takes.

```ruby
module Posts
  class PublishPost < ApplicationAction
    # ...

    def call
      post.with_lock do
        next if post.published?

        mark_published
        create_publication
        count_published_post
      end
    end

    private

    attr_reader :post, :publisher

    def mark_published
      post.update!(status: :published, published_at: Time.current)
    end

    def create_publication
      post.publications.create!(publisher:)
    end

    def count_published_post
      publisher.increment!(:published_posts_count)
    end
  end
end
```

Every caller calls the one action, and the steps commit or roll back together. Try this first. It fits more often than it seems.

## A job that runs the steps

When each step is a task of its own, and some callers run one step alone, keep each step as its own action. Put the order in one job, and have every form and job that starts the process enqueue it.

```ruby
class PublishPostJob < ApplicationJob
  def perform(post)
    Posts::RecordLinkCheck.call(post)
    return if post.link_check_failed?

    Posts::PublishPost.call(post, publisher: post.scheduled_by)
    NotifySubscribersJob.perform_later(post)
  end
end
```

The order is written once. Each step commits on its own, so no transaction is held across steps, and a step that waits, e.g. notifying subscribers, runs in its own job. See [Actions: Calling other actions](../../guide/actions/#calling-other-actions).

The process runs after the request, so a form can only tell the user that it has started, e.g. "Post will be published shortly." Use this when the user doesn't need the result in the same response.

## One job for each step

When steps call other services or take a while, a failure halfway through should carry on from that step, not start again. Give each step its own job, and save the process's progress on the record, e.g. in a `publish_status` enum. Each job checks the status first, and does nothing if its step isn't next. When it finishes, it moves the status on and enqueues the next job.

```ruby
class Post < ApplicationRecord
  ### Enumerations ###

  enum :publish_status, { checking_links: 0, publishing: 1, notifying: 2, done: 3, failed: 4 }

  # ...
end
```

```ruby
class CheckPostLinksJob < ApplicationJob
  def perform(post)
    return unless post.checking_links?

    Posts::RecordLinkCheck.call(post)
    return post.update!(publish_status: :failed) if post.link_check_failed?

    post.update!(publish_status: :publishing)
    PublishCheckedPostJob.perform_later(post)
  end
end
```

```ruby
class PublishCheckedPostJob < ApplicationJob
  def perform(post)
    return unless post.publishing?

    Posts::PublishPost.call(post, publisher: post.scheduled_by)
    post.update!(publish_status: :notifying)
    NotifySubscribersJob.perform_later(post)
  end
end
```

A retry or a duplicate job checks the status, so it carries on from where the process stopped. Write each step so it is safe to run twice. If the app stops after `Posts::PublishPost` but before the status moves on, the retry calls it again, and it does nothing because the post is already published. See [Jobs: Calling actions](../../guide/jobs/#calling-actions).

The status also shows the process's progress, e.g. on the post's page. This is the most work to set up, so use it only when a failure halfway through must carry on, not start again.

## An action that calls the other actions

When the form needs every step done before it responds, and the steps must commit or roll back together, one action can call the others. This is the rare case where an action calls other actions. Follow [Actions: Errors from other actions](../../guide/actions/#errors-from-other-actions):

- Rescue each inner action's error, and raise your own.
- Rescue outside the transaction block, so the inner writes roll back with yours.
- Call any other service before the transaction, never inside it.

If you find yourself rescuing an inner action's error and carrying on, that step isn't part of the task. Use [A job that runs the steps](#a-job-that-runs-the-steps) instead.

## Choosing a pattern

| Question | If yes |
| --- | --- |
| Does a caller ever want only some of the steps? | A job that runs the steps, or an action that calls the others. If not, one action with private methods |
| Does the user need the result in the same response? | One action with private methods, or an action that calls the others |
| Must every step commit or roll back together? | One action with private methods, or an action that calls the others |
| Do steps call other services, or take a while? | A job that runs the steps |
| Must a failure halfway through carry on from that step? | One job for each step |

## What to avoid

- **A step-runner class,** e.g. a `Pipeline` with a list of step objects. It hides the order and the error handling, and every caller has to learn how it works.
- **A result object passed from step to step.** Each step saves what it does on the record, and the next step reads it from there. See [Patterns: Values from Actions](../values-from-actions/).
- **A model callback that runs the steps.** It runs every time the record is saved, and it doesn't know who is publishing.
