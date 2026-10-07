---
applyTo: "app/actions/**/*.rb"
---

# Wisper

- Broadcast an event only after the records it describes are committed. Wrap the `broadcast` in an `ActiveRecord.after_all_transactions_commit` block, e.g. `ActiveRecord.after_all_transactions_commit { broadcast(:post_archived, post) }` after the transaction in `Posts::ArchivePost`. Never broadcast inside a transaction, or rely on broadcasting after the action's own transaction block.
- TODO: How to publish events.
- TODO: How to write listeners.
- TODO: Where to subscribe listeners.
- TODO: How to test events and listeners.
