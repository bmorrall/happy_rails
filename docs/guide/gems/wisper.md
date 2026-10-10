---
title: Wisper
parent: Gems
grand_parent: The Guide
nav_order: 10
---

# Wisper

Events with [Wisper](https://github.com/krisleech/wisper).

## Broadcasting events

> **TODO:** Describe how you handle this.

### Broadcasting after the commit

Broadcast an event only after the records it describes are committed. A listener may load them, or enqueue a job that does, and it should never react to changes that roll back. An action can't broadcast after its own transaction block, because its caller may still have a transaction open around it. See [Actions: Work after the commit](../../actions/#work-after-the-commit).

Wrap the `broadcast` in `ActiveRecord.after_all_transactions_commit`. It runs once the outermost transaction commits, never if it rolls back, and at once if no transaction is open.

```ruby
module Posts
  class ArchivePost < ApplicationAction
    include Wisper::Publisher

    # ...

    def call
      return if post.archived_at?

      ActiveRecord::Base.transaction do
        post.update!(archived_at: Time.zone.now)
        post.comments.update_all(locked: true, updated_at: Time.zone.now)
      end

      ActiveRecord.after_all_transactions_commit do
        broadcast(:post_archived, post)
      end
    end
  end
end
```

## Listeners

> **TODO:** Describe how you handle this.

## Subscriptions

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
