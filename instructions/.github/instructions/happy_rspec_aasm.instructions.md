---
applyTo: "spec/models/**/*.rb,spec/actions/**/*.rb,spec/factories/**/*.rb"
---

# AASM specs

- Give the factory a trait for each AASM state your specs need, named after the state, and set the state with `aasm.current_state =` in an `after(:build, :stub)` callback, e.g. `trait :rejected do` with `after(:build, :stub) { |post| post.aasm.current_state = :rejected }`. Give each trait the values its state needs, e.g. `rejection_reason { "Needs a stronger source." }` in `:rejected`.
- You MUST NOT set an AASM state as an attribute, e.g. `status { :approved }` in a factory or `create(:post, status: :approved)` in a spec.
- You SHOULD NOT reach an AASM state by calling events in a factory, e.g. `after(:build) { |post| post.submit; post.approve }`.
- Test a state validation on the AASM state, not the event: set the state with `aasm.current_state =` on a record built with `described_class.new`, then use Shoulda Matchers, e.g. `post.aasm.current_state = :rejected` then `expect(post).not_to allow_value("").for(:rejection_reason).with_message("can't be blank")`. You SHOULD NOT test a state validation by calling the event, e.g. `expect { post.reject! }.to raise_error(ActiveRecord::RecordInvalid)`.
- TODO: How to test events.
