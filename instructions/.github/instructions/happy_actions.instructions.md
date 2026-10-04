---
applyTo: "app/actions/**/*.rb"
---

# Actions

- Put service objects that do one task in `app/actions/`, e.g. `Posts::ArchivePost` in `app/actions/posts/archive_post.rb`.
- Keep actions separate from action forms. An action form handles what the user submits, e.g. `PublishPostForm`. An action is its own object that does a task, e.g. `Posts::ArchivePost`.
- Put each action in a module named after the resource it works on, in the plural, e.g. `Posts`. Name the action after the task, starting with a verb. The name can include the resource, e.g. `Posts::ArchivePost`, not `ArchivePost` or `Posts::ArchivePostAction`.
- Inherit every action from `ApplicationAction` in `app/actions/application_action.rb`. Define the class method `call` there to build the action, call it and return `nil`, e.g. `def self.call(...); new(...).call; nil; end`.
- Write an `initialize` that takes the action's arguments and an instance method `call` that does the task, e.g. `Posts::ArchivePost.new(post)` keeps `post` in a private `attr_reader`.
- Call an action with the class method, e.g. `Posts::ArchivePost.call(post)`, not `Posts::ArchivePost.new(post).call`.
- Never return a value from an action, and never use the value an action returns.
- When an action's task fails, raise an error, e.g. with `update!`, rather than returning `false`.
- Let an error that no caller should handle pass through the action unchanged.
- When a caller is meant to handle an error, define a custom `Error` class inside the action that inherits from `StandardError`, e.g. `class Error < StandardError; end` in `Posts::ArchivePost`. In `call`, rescue the errors the caller should handle and raise them again as the action's `Error`, e.g. `rescue ActiveRecord::RecordInvalid => e` then `raise Error, e.message`.
- Rescue an action's `Error` in a form or a job, not in a controller, e.g. `rescue Posts::ArchivePost::Error` then `errors.add(:base, "Post could not be archived.")` and `false` in a form's `submit`.
- TODO: How to test actions.
