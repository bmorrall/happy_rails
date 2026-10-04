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
module Posts
  class ArchivePost < ApplicationAction
    # ...
  end
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
module Posts
  class ArchivePost < ApplicationAction
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
module Posts
  class ArchivePost < ApplicationAction
    class Error < StandardError; end

    # ...

    def call
      post.update!(archived_at: Time.current)
      post.comments.update_all(locked: true)
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
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

### Action specs

Write an action spec as a unit spec. Stub and mock the models and other objects the action uses, and check that the action calls them with the right arguments. Name the `describe` block `".call"`, after the method the spec calls.

Use `instance_double`, e.g. `instance_double(Post)`, and avoid a plain `double`. It fails when you stub a method the class doesn't have, so the stubs can't drift away from the real code.

An action does one task, so its unit spec stays short. If the spec needs a lot of stubs to set up, the action is often doing too much. Split it into smaller actions. If the action is simple but its objects take a lot of stubbing, e.g. a chain of associations, build real records with factories instead, e.g. `create(:post)`.

```ruby
RSpec.describe Posts::ArchivePost do
  describe ".call" do
    it "archives the post and locks its comments" do
      post = instance_double(Post)
      comments = instance_double(ActiveRecord::Relation)
      allow(post).to receive(:comments).and_return(comments)

      expect(post).to receive(:update!).with(archived_at: an_instance_of(ActiveSupport::TimeWithZone))
      expect(comments).to receive(:update_all).with(locked: true)

      described_class.call(post)
    end
  end
end
```

Stub a collaborator to raise an error, to check that the action raises its own `Error` in its place.

```ruby
it "raises an Error when the post is invalid" do
  post = instance_double(Post)
  allow(post).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

  expect { described_class.call(post) }.to raise_error(described_class::Error)
end
```

The unit spec checks the action alone. The request and job specs for its callers let it run for real, so between them they check that it works with the rest of the app.

### Specs for callers

Never stub or mock an action in a request spec or a job spec, e.g. with `allow(Posts::ArchivePost).to receive(:call)` or `expect(Posts::ArchivePost).to receive(:call).with(post)`. To these specs, the action is invisible. Let it run, and check what the controller or job does: the records it changes, the response, the flash and the jobs it enqueues.

An action is a detail of how the controller or job does its work. If the spec checks the result, you can move code into an action, or out of it, without changing the spec. A spec that stubs the action only checks that the action was called. It still passes when the action is broken, or when the action is called with the wrong arguments.

```ruby
module Posts
  class ArchivesController < BaseController
    # POST /posts/:post_id/archive
    def create
      # ...

      Posts::ArchivePost.call(@post)
      redirect_to posts_path, notice: "Post was archived."
    end
  end
end
```

```ruby
RSpec.describe "Posts::Archives" do
  describe "POST /posts/:post_id/archive", :aggregate_failures do
    # ...

    it "archives the post" do
      published_post = create(:post)
      comment = create(:comment, post: published_post)

      expect {
        post post_archive_path(published_post)
      }.to change { published_post.reload.archived_at }.from(nil)

      expect(comment.reload).to be_locked
      expect(response).to redirect_to(posts_path)
      expect(flash.to_hash).to match("notice" => "Post was archived.")
    end
  end
end
```

To test how a caller handles the action's `Error`, set up records that make the action fail for real. Don't stub the action to raise it, e.g. with `allow(Posts::ArchivePost).to receive(:call).and_raise(Posts::ArchivePost::Error)`.
