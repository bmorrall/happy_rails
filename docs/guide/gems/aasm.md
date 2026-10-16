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

  aasm column: :status, whiny_persistence: true do
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

  aasm column: :status, whiny_persistence: true do
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
      <%= button_to "Reject", post_rejection_path(post) %>
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

## Testing

See [Testing: AASM](../../../testing/gems/aasm/).
