---
applyTo: "app/models/**/*.rb,app/actions/**/*.rb"
---

# Turbo

- Broadcast from the action that changes the records, inside an `ActiveRecord.after_all_transactions_commit` block, e.g. `ActiveRecord.after_all_transactions_commit { post.broadcast_refresh }` in `Posts::ArchivePost`. You MUST NOT broadcast from a model callback, e.g. `broadcasts_refreshes`, `broadcasts_to` or `after_update_commit -> { broadcast_refresh }`.
