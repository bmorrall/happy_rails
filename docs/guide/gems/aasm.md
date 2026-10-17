---
title: AASM
parent: Gems
grand_parent: The Guide
nav_order: 1
---

# AASM

State machines with [AASM](https://github.com/aasm/aasm).

The rest of the guide doesn't use AASM. This page shows how `Post` changes when an app uses it: AASM takes over the `status` column, and publishing a post becomes the `publish` event.

## Layout

Put `include AASM` and the `aasm` block at the top of the model, under `### Modules (AASM) ###`, before `### Scopes ###`. The block defines a scope and a constant for each state, e.g. `Post.published` and `Post::STATE_PUBLISHED`. When they come first, the model's own scopes and constants can override them. Add a comment saying why it's at the top, as in [Models: Layout](../../models/#layout).

```ruby
class Post < ApplicationRecord
  ### Modules (AASM) ###

  # AASM must come first: the model can override its scopes and constants
  include AASM

  aasm column: :status, whiny_persistence: true, no_direct_assignment: true do
    state :draft, initial: true
    state :submitted, :approved, :rejected, :published

    event :publish do
      transitions from: :approved, to: :published
    end
  end

  ### Scopes ###

  # ...
end
```

## State column

Store the state in a string column, e.g. `status`. AASM saves each state by its name, e.g. `"published"`. You MUST NOT declare an enum for the column.

AASM defines the states, so they're listed once, in the `aasm` block, along with their scopes and predicates. An enum would list them again, and add a bang method for each state, e.g. `post.published!`, that changes the state without the event.

```ruby
# Don't do this
class Post < ApplicationRecord
  # ...

  enum :status, { draft: "draft", published: "published" }
end
```

Change the state only with an event. You MUST NOT write the state column yourself, e.g. `post.update!(status: "published")`, `post.status = "published"`, `posts.update_all(status: "published")`, `post.update_column(:status, "published")` or `post.aasm.current_state = :published`. Writing the column skips the event's transitions and guards. It also skips the action, so the work that goes with the event never happens, e.g. notifying subscribers.

Set `no_direct_assignment: true` on the `aasm` block, as in [Layout](#layout). Assigning the column, e.g. `post.status = "published"` or `post.update!(status: "published")`, then raises `AASM::NoDirectAssignmentError`. It doesn't catch `update_all`, `update_column` or `aasm.current_state=`, because they skip the column's writer.

```ruby
# Don't do this
module Posts
  class PublishPost < ApplicationAction
    # ...

    def call
      post.update!(status: "published")
      # ...
    end
  end
end
```

## Guards

Use a guard for a condition on the record's saved values, e.g. a scheduled post can't be published before its `publish_at`. The record already holds the answer, so `may_publish?` knows it before anyone presses a button.

```ruby
class Post < ApplicationRecord
  ### Modules (AASM) ###

  # ...

  aasm column: :status, whiny_persistence: true, no_direct_assignment: true do
    # ...

    event :publish do
      transitions from: :approved, to: :published, guard: :publish_time_reached?
    end
  end

  # ...

  ### Public Methods ###

  def publish_time_reached?
    publish_at.nil? || publish_at <= Time.zone.now
  end
end
```

Allow a record the condition doesn't apply to, e.g. a post with no `publish_at`. Otherwise it can never take the event.

A guard applies to every caller of the event. Here, a Publishing Manager can't publish a scheduled post early either. When one way in needs to skip the guard, give it its own event, e.g. `publish_on_schedule` with the guard and `publish` without it.

You MUST NOT check the request's input in a guard, e.g. the reason for a rejection. `may_reject?` would then be `false` until the input arrives, so the view can't offer the form that collects it. See [Events that need input](#events-that-need-input). To require a value in a state, validate it on the state, as in [Models: State validations](../../models/#state-validations).

## Events

Call an event only from an action in the resource's module, e.g. `post.publish!` in `Posts::PublishPost`. You MUST NOT call an event anywhere else, e.g. in a controller, a form, a job, a model method or another resource's action. Checking an event or a state is fine anywhere, e.g. `post.may_publish?` or `post.published?`.

An event is a task: it changes the record, and the app usually does more when it happens, e.g. notifies subscribers. The action is the one place that does the task, so every caller gets the same checks and the same side effects. See [Actions](../../actions/).

### Permissions

Name the permission for an event after the event, e.g. `publish?` for the `publish` event. The event, the action and the permission then share one name, e.g. `publish`, `Posts::PublishPost` and `publish?`, so you can find each one from the others. This works with any authorisation library. With Pundit, it's `PostPolicy#publish?` under `### Publishing ###`, as in [Pundit: Parent records](../pundit/#parent-records).

Leave the event's state check out of the permission, e.g. `may_publish?` or `draft?` in `publish?`. AASM already enforces it when the event runs, and the action turns its failure into the action's `Error`, as in [Failed events](#failed-events). A permission still reads the record when that decides access, e.g. `create_comment?` checks that the post is published.

```ruby
class PostPolicy < ApplicationPolicy
  ### Publishing ###

  def publish?
    user.app_admin? || user.publishing_manager?
  end
end
```

### Views

Show an event in a view only when the user has permission and the record's state allows it. The permission leaves out the event's state, so the view checks both, e.g. `publish?` and `may_publish?`.

With [Draper](../draper/#permissions), define the decorator's `can_` check for the event yourself, in place of delegating it to the policy. Check the permission first, then the state. The view then calls one method, e.g. `post.can_publish?`.

```ruby
class PostDecorator < ApplicationDecorator
  ### Policy ###

  def can_publish?
    policy.publish? && object.may_publish?
  end
end
```

```erb
<% if post.can_publish? %>
  <%= button_to "Publish", post_publication_path(post) %>
<% end %>
```

### Groups of events

Some events show together in one part of the page, e.g. a review panel with buttons to approve, reject or request changes. Give the decorator a check for the group, and build it from the events' `can_` checks, e.g. `can_review?`. The panel then shows only when it has a button in it, and it stays right when one event's permission changes.

You MUST NOT give the group a permission or state check of its own, e.g. `policy.review? && object.submitted?`. It can drift from the events, and show an empty panel or hide a button the user can press.

```ruby
class Post < ApplicationRecord
  ### Modules (AASM) ###

  # ...

  aasm column: :status, whiny_persistence: true, no_direct_assignment: true do
    # ...

    event :approve do
      transitions from: :submitted, to: :approved
    end

    event :reject do
      transitions from: :submitted, to: :rejected
    end

    event :request_changes do
      transitions from: :submitted, to: :draft
    end
  end
end
```

```ruby
class PostDecorator < ApplicationDecorator
  ### Policy ###

  def can_approve?
    policy.approve? && object.may_approve?
  end

  def can_reject?
    policy.reject? && object.may_reject?
  end

  def can_request_changes?
    policy.request_changes? && object.may_request_changes?
  end

  def can_review?
    can_approve? || can_reject? || can_request_changes?
  end
end
```

```erb
<% if post.can_review? %>
  <section class="review-panel">
    <% if post.can_approve? %>
      <%= button_to "Approve", post_approval_path(post) %>
    <% end %>

    <% if post.can_reject? %>
      <%= link_to "Reject", new_post_rejection_path(post) %>
    <% end %>

    <% if post.can_request_changes? %>
      <%= button_to "Request changes", post_change_request_path(post) %>
    <% end %>
  </section>
<% end %>
```

### Events that aren't available yet

A view MAY show an event's button disabled, when the user has permission but the record isn't ready yet, e.g. a Publish button on a submitted post that still needs approval. The user then sees what comes next.

Keep the event's `can_` check for the button that works, e.g. `can_publish?`. Add a second check for the disabled button, with the permission first, then the state it waits in. Name it after what it waits for, e.g. `can_publish_once_approved?`. The view picks between them, as with an alternative link in [Draper: Permissions](../draper/#permissions).

```ruby
class PostDecorator < ApplicationDecorator
  ### Policy ###

  def can_publish?
    policy.publish? && object.may_publish?
  end

  def can_publish_once_approved?
    policy.publish? && object.submitted?
  end
end
```

```erb
<% if post.can_publish? %>
  <%= button_to "Publish", post_publication_path(post) %>
<% elsif post.can_publish_once_approved? %>
  <%= button_to "Publish", post_publication_path(post), disabled: true %>
<% end %>
```

The disabled button is only a hint. If the form is sent anyway, the event fails and the action raises its `Error`, as in [Failed events](#failed-events).

### Failed events

Set `whiny_persistence: true` on the `aasm` block, as in [Layout](#layout). A bang event, e.g. `publish!`, then raises `ActiveRecord::RecordInvalid` when the record fails to save. Without it, the event returns `false`, and the failure is easy to miss.

In the action, rescue `AASM::InvalidTransition` and `ActiveRecord::RecordInvalid`, and raise them again as the action's `Error`, as in [Actions: Error handling](../../actions/#error-handling). AASM raises `AASM::InvalidTransition` when the record can't take the event from its current state, e.g. publishing a post that's already published. The caller then rescues one error class, and doesn't need to know the action uses AASM.

```ruby
module Posts
  class PublishPost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      post.publish!
      # ...
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
```

```ruby
# Don't do this
module Posts
  class PublicationsController < BaseController
    def create
      @post.publish!
      # ...
    end
  end
end
```

### Locks

Call an event inside `with_lock` when two users could act on the record at once, e.g. two Copy Editors reviewing the same post. Without the lock, both load it as `submitted`, both events pass, and the last save wins. `with_lock` reloads the record, so the event checks the current state, as in [Actions: Locks](../../actions/#locks).

Set the event's values inside the lock, after it reloads the record. Inside the lock, do nothing if the event has already happened, e.g. `next if post.rejected?`, so the action is safe to retry. If another user moved the record somewhere else first, the event raises `AASM::InvalidTransition`, and the action raises its `Error`.

| State inside the lock | What happens |
| --- | --- |
| `rejected` | `next`: the work is already done, so the action succeeds |
| `submitted` | The action rejects the post |
| Anything else, e.g. `approved` | `reject!` raises `AASM::InvalidTransition`, and the action raises its `Error` |

Check the state the event leads to, e.g. `rejected?`, not whether the event is allowed, e.g. `may_reject?`. `next unless post.may_reject?` would also skip a post another user approved first. The action would then succeed without rejecting the post, and the user would never know.

You SHOULD NOT use AASM's `requires_lock` option. It hides the lock in the model, away from the action it protects. It also locks when the event runs, after the action has set the event's values, and Rails won't lock a record with unsaved changes.

`with_lock` opens a transaction, so the action doesn't need another one. Every write inside the lock commits or rolls back with the event.

### Events that need input

Some events need input from the user, e.g. a rejection needs a reason. Validate the input in a form, and pass it to the action. The action saves it and calls the event, inside a lock as in [Locks](#locks). The permission and `may_reject?` stay the same, so the view shows the form whenever the user can reject the post.

```ruby
class RejectPostForm < ApplicationForm
  # ...

  ### Attributes ###

  attribute :reason, :string

  ### Validations ###

  validates :reason,
    presence: true

  ### Public Methods ###

  def submit
    return false unless valid?

    Posts::RejectPost.call(post, reason:, rejected_by: current_user)
    post
  rescue Posts::RejectPost::Error
    errors.add(:base, "Post could not be rejected.")
    false
  end
end
```

```ruby
module Posts
  class RejectPost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      post.with_lock do
        next if post.rejected?

        post.rejection_reason = reason
        post.rejected_by = rejected_by
        post.reject!
      end
    rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
```

When every rejected post has to have a reason, validate it on the state in the model too. You MAY back it with a database constraint. See [Models: State validations](../../models/#state-validations) and [Models: Database constraints](../../models/#database-constraints).

## Testing

See [Testing: AASM](../../../testing/gems/aasm/).
