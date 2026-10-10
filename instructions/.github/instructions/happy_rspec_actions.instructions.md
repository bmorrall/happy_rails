---
applyTo: "spec/actions/**/*.rb"
---

# Action specs

- In the spec for an action that checks `unmodified:`, stub `has_changes_to_save?` to return `false` on each record double it checks, e.g. `instance_double(Post, has_changes_to_save?: false)`.
- Write action specs as unit specs. Stub everything the action calls, and check that it calls each one with the right arguments, e.g. `post = instance_double(Post)` then `expect(post).to receive(:update!).with(archived_at: Time.zone.now)` before `described_class.call(post)`. Avoid creating records in action specs, even when the action runs a query.
- In action specs, name the `describe` block after the method the spec calls, e.g. `describe ".call"`.
- If an action spec needs a lot of stubs to set up, split the action into smaller actions. If a chain of calls is hard to stub, move the chain into a method on the model, following the models instructions, so the spec stubs one method.
- In action specs, check the action's `Error` by stubbing a collaborator to raise the original error, e.g. `allow(post).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)` then `expect { described_class.call(post) }.to raise_error(described_class::Error)`.
- In action specs, stub other actions the action calls too, e.g. `expect(Posts::UnpublishPost).to receive(:call).with(post)` in the spec for `Posts::ArchivePost`. To check the action wraps the other action's error, stub the other action to raise it, e.g. `allow(Posts::UnpublishPost).to receive(:call).and_raise(Posts::UnpublishPost::Error)`.
- When an action writes to a relation, stub the method that returns it to return an `instance_double(ActiveRecord::Relation)` and expect the write, e.g. `allow(Comment).to receive(:on_posts).with(posts).and_return(comments)` then `expect(comments).to receive(:update_all).with(locked: true, updated_at: Time.zone.now)`. Pass a relation double in as the records, e.g. `posts = instance_double(ActiveRecord::Relation)`.
- When an action loops with `find_each`, stub it to yield doubles, e.g. `allow(posts).to receive(:find_each).and_yield(post)`.
- When an action takes a lock, stub `with_lock` to yield, e.g. `allow(post).to receive(:with_lock).and_yield`. To test the check inside the lock, return one answer for the check before the lock and another for the check inside it, e.g. `allow(post).to receive(:published?).and_return(false, true)`.
- When an action calls a chain of methods, stub the chain with `allow(...).to receive_message_chain`, never `expect`, and check each step's arguments afterwards with `have_received`, e.g. `allow(PublishScheduledPostJob).to receive_message_chain(:set, :perform_later)`, then `expect(PublishScheduledPostJob).to have_received(:set).with(wait_until: publish_at)` and `expect(PublishScheduledPostJob.set).to have_received(:perform_later).with(post)`.
