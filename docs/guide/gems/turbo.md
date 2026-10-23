---
title: Turbo
parent: Gems
grand_parent: The Guide
nav_order: 10
---

# Turbo

Live updates with [Turbo Rails](https://github.com/hotwired/turbo-rails).

## Broadcasting

Broadcast from the action that changes the records, e.g. `post.broadcast_refresh` in `Posts::ArchivePost`. You MUST NOT broadcast from a model callback, e.g. `broadcasts_refreshes`, `broadcasts_to` or `after_update_commit -> { broadcast_refresh }`.

A model callback broadcasts on every save: from a form, a job, the console, a seed file or a factory in a spec. The action is the task, so it knows when users need to see the change, and the broadcast shows in the code that does the work. See [Models: Callbacks](../../models/#callbacks).

```ruby
# Don't do this
class Post < ApplicationRecord
  broadcasts_refreshes
end
```

Broadcast after the records are committed, in an `ActiveRecord.after_all_transactions_commit` block. See [Actions: Work after the commit](../../actions/#work-after-the-commit).

```ruby
module Posts
  class ArchivePost < ApplicationAction
    # ...

    def call
      ActiveRecord::Base.transaction do
        post.update!(archived_at: Time.zone.now)
        post.comments.update_all(locked: true, updated_at: Time.zone.now)
      end

      ActiveRecord.after_all_transactions_commit do
        post.broadcast_refresh
      end
    end
  end
end
```

## Testing

See [Testing: Turbo](../../../testing/gems/turbo/).
