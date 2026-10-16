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

  aasm column: :status do
    state :draft, initial: true
    state :published

    event :publish do
      transitions from: :draft, to: :published
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

```ruby
module Posts
  class PublishPost < ApplicationAction
    # ...

    def call
      post.publish!
      # ...
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
