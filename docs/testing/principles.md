---
title: Principles
parent: Testing
nav_order: 1
---

# Principles

How the ideas behind the guide shape my specs.

For the code itself, see [Principles](../../guide/principles/).

## Personas

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
