---
applyTo: "app/models/**/*.rb,app/actions/**/*.rb,app/views/**/*,app/components/**"
---

# Turbo

- Broadcast from the action that changes the records, inside an `ActiveRecord.after_all_transactions_commit` block, e.g. `ActiveRecord.after_all_transactions_commit { post.broadcast_refresh }` in `Posts::ArchivePost`. You MUST NOT broadcast from a model callback, e.g. `broadcasts_refreshes`, `broadcasts_to` or `after_update_commit -> { broadcast_refresh }`.
- You SHOULD NOT wrap content in a Turbo Frame that nothing loads into. Only add a frame when its `src:`, or a link or a form inside it, loads into it, e.g. `turbo_frame_tag dom_id(@post, :comments), src: post_comments_path(@post)` in `app/views/posts/show.html.erb`.
- Give every link and form inside a frame a page to load that has a frame with the same id, e.g. `turbo_frame_tag dom_id(@post, :comments)` in `app/views/posts/comments/index.html.erb`. When a link leaves the frame, set `data: { turbo_frame: "_top" }`, e.g. `link_to "Sign in to comment", new_user_session_path, data: { turbo_frame: "_top" }`.
