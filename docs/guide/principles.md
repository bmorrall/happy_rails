---
title: Principles
parent: The Guide
nav_order: 1
---

# Principles

The ideas that shape every other decision in this guide.

## Defaults first

> **TODO:** Describe how you handle this.

## When to add a gem

> **TODO:** Describe how you handle this.

## Naming

> **TODO:** Describe how you handle this.

## Personas

A persona stands for one type of person who uses the app. Name each persona after its role, e.g. a Publishing Manager or an Author. A role lets a user take certain actions on certain records.

Some roles apply to the whole app. A Publishing Manager can publish any post. A role on the whole app might be a role the user is given, or a flag on the user, e.g. an Employee is a user with `employee` set. Other roles apply to one record. A user is the Author of the posts they wrote, and of no others. In an app with projects, any user might be added to one project as its Project Manager. A user can hold a role on one record and not on the next.

Group the personas, and rank the groups from the most access to the least. Each app has its own groups. A publishing app might use these:

1. **App Admins**: run the whole app.
2. **Editors**: manage other people's content, e.g. a Publishing Manager.
3. **Authors**: manage the posts they wrote.
4. **Users**: have signed in but have no role.

The **Guest**, a visitor who hasn't signed in, comes last.

| Group | Persona | Can |
| --- | --- | --- |
| App Admins | App Admin | Do anything |
| Editors | Publishing Manager | Publish any post |
| Authors | Author | Edit the posts they wrote |
| Users | User | Read published posts, comment on them, and write posts |
| | Guest | Read published posts |

The User and the Guest always come last, because they have the least access.

When a group has more than one persona, rank them inside the group too, e.g. a Publishing Manager before a Copy Editor in the Editors group. Decide the order once, and use the same order every time.

A persona can have more than one role, e.g. an App Admin who is also the Author of the post. Put it in the group of its highest role, straight after the persona with only that role.

Only add a persona when the app gets a new role. Don't add one to fill out a spec.

Personas make it easier to see which scenarios need covering. For each action, ask what each persona should be able to do, and on which records. The Guest and the User often show the gaps: an action left open by mistake, or one that anyone who signs in can use. A persona who may act, but not on this record, finds the rest, e.g. an Author editing someone else's post.

### Keep the ranks

List personas in rank order everywhere they appear: in the table above, in permission checks, and in request and feature specs. Then every list of personas reads the same way. You can compare a policy with its spec at a glance, and a missing persona stands out.

```ruby
class Posts::PublicationPolicy < ApplicationPolicy
  def create?
    user.app_admin? || user.publishing_manager?
  end
end
```

### Personas in specs

For how to write a spec for each persona with RSpec and FactoryBot, see [RSpec and FactoryBot: Personas](../gems/rspec/#personas).
