---
title: Turbo
parent: Gems
grand_parent: The Guide
nav_order: 11
---

# Turbo

Live updates and frames with [Turbo Rails](https://github.com/hotwired/turbo-rails).

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
      Post.transaction do
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

## Frames

Wrap part of a page in a frame only when something loads into it, e.g. its `src:`, or a link or a form inside it. You SHOULD NOT wrap content in a frame that nothing loads into. A frame changes how every link and form inside it works, so a frame with no use only adds ways for them to break.

Give every link and form inside a frame a page to load that has a frame with the same id. When a link leaves the frame, e.g. for a page of its own, set `data: { turbo_frame: "_top" }`. Turbo looks for the frame in the response, and shows "Content missing" in its place when it isn't there.

```erb
<%# app/views/posts/show.html.erb %>
<%= turbo_frame_tag dom_id(@post, :comments), src: post_comments_path(@post) %>
```

```erb
<%# app/views/posts/comments/index.html.erb %>
<%= turbo_frame_tag dom_id(@post, :comments) do %>
  <%= render @comments %>
  <%= link_to "Sign in to comment", new_user_session_path, data: { turbo_frame: "_top" } %>
<% end %>
```

The sign in page has no comments frame, so the link breaks out of the frame and loads the whole page.

## Testing

See [Testing: Turbo](../../../testing/gems/turbo/).
