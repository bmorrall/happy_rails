---
title: AASM
parent: Gems
grand_parent: Testing
nav_order: 1
---

# AASM

How I test state machines with AASM.

For the code itself, see [AASM](../../../guide/gems/aasm/).

## State column

The model sets `no_direct_assignment: true`, so assigning the state column raises `AASM::NoDirectAssignmentError`, as in [AASM: State column](../../../guide/gems/aasm/#state-column). A factory or spec that passes the state as an attribute raises it too, e.g. `create(:post, status: :approved)`.

Give the factory a trait for each state your specs need, named after the state, e.g. `:submitted` and `:rejected`. Set the state with `aasm.current_state =` in an `after(:build, :stub)` callback. It writes the attribute without the column's writer, so it doesn't raise. The `:build` callback runs for `build` and `create`, and `:stub` runs for `build_stubbed`. AASM sets the initial state when the record is initialised, before the callback runs, so the trait's state replaces it.

Give each trait the values its state needs, e.g. a `rejection_reason` for `:rejected`. The state validations still run when the record saves, so a trait can't make a record the app couldn't hold. See [Models: State validations](../../../guide/models/#state-validations).

```ruby
FactoryBot.define do
  factory :post do
    # ...

    trait :submitted do
      after(:build, :stub) { |post| post.aasm.current_state = :submitted }
    end

    trait :rejected do
      rejection_reason { "Needs a stronger source." }

      after(:build, :stub) { |post| post.aasm.current_state = :rejected }
    end
  end
end
```

```ruby
post = create(:post, :rejected)
```

You MUST NOT set the state as an attribute, e.g. `status { :approved }` in a factory or `create(:post, status: :approved)` in a spec.

You SHOULD NOT reach a state by calling events in the factory, e.g. `after(:build) { |post| post.submit; post.approve }`. Each trait would then have to pass every guard on the way, so a new guard breaks traits that have nothing to do with it.

Test a state validation on the state, not the event. Set the state with `aasm.current_state =` on a record built with `described_class.new`, as in [Models](../../models/), then check the value with Shoulda Matchers, as in [Shoulda Matchers: Validations](../shoulda_matchers/#validations). The validation runs on every save in the state, however the record got there, so the spec doesn't need the event, its guards or the action. See [Models: State validations](../../../guide/models/#state-validations).

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe "#rejection_reason" do
    it "is required when rejected" do
      post.aasm.current_state = :rejected

      expect(post).not_to allow_value("").for(:rejection_reason).with_message("can't be blank")
    end
  end
end
```

You SHOULD NOT test a state validation by calling the event, e.g. `reject!` with a blank `rejection_reason`. The event can fail for another reason, e.g. the record is in the wrong state, so the spec can pass without the validation.

```ruby
# Don't do this
it "is required when rejected" do
  post = create(:post, :submitted, rejection_reason: nil)

  expect { post.reject! }.to raise_error(ActiveRecord::RecordInvalid)
end
```

## Events

> **TODO:** Describe how you handle this.
