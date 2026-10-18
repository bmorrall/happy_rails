---
title: AASM
parent: Gems
grand_parent: Testing
nav_order: 1
---

# AASM

How I test state machines with AASM.

For the code itself, see [AASM](../../../guide/gems/aasm/).

## Events

Test each event in the model spec, with the matchers AASM ships for RSpec. Load them in `spec/support/aasm.rb`.

```ruby
# spec/support/aasm.rb
require "aasm/rspec"
```

Put the examples for each event in a `describe` block named after the event, inside `describe "AASM"`, as for any gem's Modules heading. See [Models: Spec layout](../../models/#spec-layout). Check the event with `transition_from` on a record built with `described_class.new`. The matcher sets the starting state, calls the event and checks the state it ends in, without saving. Check each state the event starts from, one example each.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "AASM" do
    describe "#publish" do
      it { is_expected.to transition_from(:approved).to(:published).on_event(:publish) }
    end
  end
end
```

Check that every other state refuses the event, with `not_to`, one example each. A state you leave out could start taking the event by mistake, and no spec would notice.

```ruby
describe "AASM" do
  describe "#publish" do
    it { is_expected.to transition_from(:approved).to(:published).on_event(:publish) }
    it { is_expected.not_to transition_from(:draft).to(:published).on_event(:publish) }
    it { is_expected.not_to transition_from(:submitted).to(:published).on_event(:publish) }
    it { is_expected.not_to transition_from(:rejected).to(:published).on_event(:publish) }
    it { is_expected.not_to transition_from(:published).to(:published).on_event(:publish) }
  end
end
```

When the event has a [guard](../../../guide/gems/aasm/#guards), check every case it allows and refuses, e.g. a post with no publish time, one whose publish time is reached and one whose isn't. Build the record with the values the guard reads, and stop the clock when it reads the time.

```ruby
describe "AASM" do
  describe "#publish" do
    it "publishes an approved post with no publish time" do
      post = described_class.new(publish_at: nil)

      expect(post).to transition_from(:approved).to(:published).on_event(:publish)
    end

    it "publishes an approved post when its publish time is reached" do
      travel_to Time.zone.now

      post = described_class.new(publish_at: Time.zone.now)

      expect(post).to transition_from(:approved).to(:published).on_event(:publish)
    end

    it "does not publish an approved post before its publish time" do
      travel_to Time.zone.now

      post = described_class.new(publish_at: 1.minute.from_now)

      expect(post).not_to transition_from(:approved).to(:published).on_event(:publish)
    end
  end
end
```

You SHOULD NOT call the event and check the state by hand. The matcher reads as the transition it checks, and its failure message names the event and both states.

```ruby
describe "AASM" do
  describe "#publish" do
    # Don't do this
    it "publishes an approved post" do
      post = described_class.new(status: "approved")
      post.publish

      expect(post.status).to eq("published")
    end
  end
end
```

The matchers don't save the record. The action calls the bang event, e.g. `publish!`, and the specs for its callers cover the save.
