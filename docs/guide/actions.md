---
title: Actions
parent: The Guide
nav_order: 5
---

# Actions

How service objects are written and called.

An action is a service object that does one task, e.g. archiving a post. Any code can call it, e.g. a controller, a form or a job.

An action is not an [action form](../forms/#action-forms). An action form handles what the user submits for an action. An action is a separate object that does a task.

Put actions in `app/actions/`, e.g. `Posts::ArchivePost` in `app/actions/posts/archive_post.rb`.

## Naming

Put each action in a module named after the resource it works on, in the plural, like its controller, e.g. `Posts`. Name the action after the task, starting with a verb. The name can include the resource as well, e.g. `Posts::ArchivePost`. The module groups every action for a resource in one directory, and the name says what the action does.

```ruby
class Posts::ArchivePost < ApplicationAction
  # ...
end
```

## Calling an action

Every action responds to `call`. Callers use the class method, e.g. `Posts::ArchivePost.call(post)`, not `new` and then `call`. The class method builds the action with its arguments and runs it, so every action is called the same way.

Give every action a base class, `ApplicationAction`, in `app/actions/application_action.rb`. It defines the class method `call` once, so each action only writes `initialize` and an instance method `call`.

```ruby
class ApplicationAction
  def self.call(...)
    new(...).call
    nil
  end
end
```

```ruby
class Posts::ArchivePost < ApplicationAction
  def initialize(post)
    @post = post
  end

  def call
    post.update!(archived_at: Time.current)
    post.comments.update_all(locked: true)
  end

  private

  attr_reader :post
end
```

## Return values

An action does its task and returns nothing. The caller doesn't check a result, so don't return one from `call`, and don't use the value it returns. `ApplicationAction.call` returns `nil`, so a caller can't come to depend on whatever the last line of `call` returns.

```ruby
Posts::ArchivePost.call(post)
redirect_to posts_path, notice: "Post was archived."
```

## Error handling

If the task fails, raise an error, e.g. with `update!`, rather than returning `false`. Let an error that no caller should handle pass through as it is.

When a caller is meant to handle an error, write a custom `Error` class inside the action, and inherit it from `StandardError`. In `call`, rescue the errors the caller should handle and raise them again as the action's `Error`. The caller then rescues one error class, e.g. `Posts::ArchivePost::Error`, and doesn't need to know which errors the action's code can raise. Ruby keeps the original error as the new error's `cause`, so it still shows up in the error report.

```ruby
class Posts::ArchivePost < ApplicationAction
  class Error < StandardError; end

  # ...

  def call
    post.update!(archived_at: Time.current)
    post.comments.update_all(locked: true)
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.message
  end
end
```

Rescue the action's `Error` where the work is done, in a form or a job, as in [Controllers and Routes: Rescuing errors](../controllers/#rescuing-errors).

```ruby
def submit
  return false unless valid?

  Posts::ArchivePost.call(post)
  post
rescue Posts::ArchivePost::Error
  errors.add(:base, "Post could not be archived.")
  false
end
```

## Testing

> **TODO:** Describe how you handle this.
