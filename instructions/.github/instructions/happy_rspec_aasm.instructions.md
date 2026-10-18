---
applyTo: "spec/models/**/*.rb"
---

# AASM specs

- In model specs, test each AASM event in a `describe` block named after the event, inside `describe "AASM"`, with AASM's RSpec matchers on a record built with `described_class.new`, e.g. `describe "#publish"` with `subject(:post) { described_class.new }` in `spec/models/post_spec.rb`.
- Check each state an event starts from with `transition_from`, one example each, e.g. `it { is_expected.to transition_from(:approved).to(:published).on_event(:publish) }` in `describe "#publish"` inside `describe "AASM"`.
- Check that every other state refuses the event with `not_to`, one example each, e.g. `it { is_expected.not_to transition_from(:draft).to(:published).on_event(:publish) }` in `describe "#publish"` inside `describe "AASM"`.
- When an event has a guard, check every case it allows and refuses, e.g. for `publish_time_reached?`, a post with no `publish_at`, one whose `publish_at` is reached and one whose isn't. Build the record with the values the guard reads, and call `travel_to` when it reads the time, e.g. `described_class.new(publish_at: 1.minute.from_now)` with `expect(post).not_to transition_from(:approved).to(:published).on_event(:publish)` in `it "does not publish an approved post before its publish time"` in `describe "#publish"` inside `describe "AASM"`.
- You SHOULD NOT call an event and check the state by hand, e.g. `post.publish` then `expect(post.status).to eq("published")`. Use the AASM matchers.
