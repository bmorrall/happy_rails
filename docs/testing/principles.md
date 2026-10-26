---
title: Principles
parent: Testing
nav_order: 1
---

# Principles

How the ideas behind the guide shape my specs.

For the code itself, see [Principles](../../guide/principles/).

## Unit and integration specs

Unit specs check the details, and integration specs check the outline. A unit spec, e.g. a model, service or action spec, checks each thing its code does: the values it works out, the errors it raises, and what each error holds. An integration spec, e.g. a request, feature or job spec, checks that the pieces work together: whether the code succeeded or failed, and what it did as a whole.

Leave each detail to the unit spec for the code that works it out. A change to that detail then fails one spec, not every spec that passes through the code. For example, a request spec checks which records an error report includes, with each record's `to_honeybadger_context`. The model spec checks what that hash holds. See [Honeybadger: Reporting errors](../gems/honeybadger/#reporting-errors).

## The signed-in user

Only sign in a user, e.g. with `sign_in`, in request and feature specs. They test the code that handles a request, which is the only code that knows who is signed in. In other specs, pass the user in as an argument, as the app code does.

```ruby
RSpec.describe Posts::PublishPost do
  it "records the publisher" do
    post = create(:post)
    user = create(:user, :publishing_manager)

    described_class.call(post, publisher: user)

    expect(post.publications.last.publisher).to eq(user)
  end
end
```

## Personas

Personas make it easier to see which scenarios need covering. When you add or change an action, cover in request and feature specs what each persona can do, and on which records. The Guest and the User often show the gaps: an action left open by mistake, or one that anyone who signs in can use. Include a persona who can act on some records but not this one, e.g. a User editing a post someone else wrote.

A persona whose role plays no part in the action doesn't need a scenario of its own in request and feature specs. It gets the same answer as the User, so the User's scenario covers it, and so does the policy spec, e.g. a Copy Editor or an Author publishing a post.

## Keep the ranks

List personas in rank order in request and feature specs too, as in permission checks. You can then compare a policy with its spec at a glance, and a missing persona stands out.

```ruby
RSpec.describe "Posts::Publications" do
  describe "POST /posts/:post_id/publication", :aggregate_failures do
    context "as an app admin" do
      # ...
    end

    context "as a publishing manager" do
      # ...
    end

    context "as a user" do
      # ...
    end

    context "when not signed in" do
      # ...
    end
  end
end
```

## Personas in specs

For how to write persona specs with RSpec and FactoryBot, see [RSpec and FactoryBot: Personas](../gems/rspec/#personas).
