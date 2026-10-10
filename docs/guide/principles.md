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

## The signed-in user

Only the code that handles a request knows who is signed in. That is controllers, forms, views and helpers, and the request and feature specs that test them. Everything else has no signed-in user, e.g. models, actions, jobs, mailers and view components.

That code often runs outside a request. A job runs after the request has finished. A mailer or a component may render in a job or a Turbo Stream broadcast. A console or a rake task has no session at all. Code that reaches for the signed-in user breaks there, or picks up the wrong user.

When that code needs a user, pass the user in as an argument. Name the argument after the role the user plays in the task, e.g. `publisher:`, not `current_user:` or `user:`. The name says why the user is there, and the code works the same whoever calls it.

```ruby
class PublishPostForm < ApplicationForm
  # ...

  def submit
    return false unless valid?

    Posts::PublishPost.call(post, publisher: current_user)
    post
  end
end
```

```ruby
module Posts
  class PublishPost < ApplicationAction
    def initialize(post, publisher:)
      @post = post
      @publisher = publisher
    end

    def call
      ActiveRecord::Base.transaction do
        post.update!(status: :published)
        post.publications.create!(publisher:)
      end
    end

    private

    attr_reader :post, :publisher
  end
end
```

Don't reach the signed-in user through a global, e.g. `Current.user` from `ActiveSupport::CurrentAttributes`. The code then depends on a user it doesn't ask for, and it only works when a request has set one.

## Personas

A persona stands for one type of person who uses the app. Name each persona after its role, e.g. a Publishing Manager or an Author. A role lets a user take certain actions on certain records.

Some roles apply to the whole app. A Publishing Manager can publish any post. A role on the whole app might be a role the user is given, or a flag on the user, e.g. an Employee is a user with `employee` set. Other roles apply to one record. A user is the Author of the posts they wrote, and of no others. In an app with projects, any user might be added to one project as its Project Manager. A user can hold a role on one record and not on the next.

Group the personas, and rank the groups from the most access to the least. Each app has its own groups. A publishing app might use these:

1. **App Admins**: run the whole app.
2. **Editors**: manage other people's content, e.g. a Publishing Manager or a Copy Editor.
3. **Authors**: manage the posts they wrote.
4. **Users**: have signed in but have no role.

The **Guest**, a visitor who hasn't signed in, comes last.

| Group | Persona | Can |
| --- | --- | --- |
| App Admins | App Admin | Do anything |
| Editors | Publishing Manager | Publish any post |
| Editors | Copy Editor | Edit any post |
| Authors | Author | Edit the posts they wrote |
| Users | User | Read published posts, comment on them, and write posts |
| | Guest | Read published posts |

The User and the Guest always come last, because they have the least access.

When a group has more than one persona, rank them inside the group too, e.g. a Publishing Manager before a Copy Editor in the Editors group. Decide the order once, and use the same order every time. Then the existing specs show the order, because their persona contexts follow it.

A persona can have more than one role, e.g. a Copy Editor who is also the Author of the post. Only add one when it changes the outcome, compared with the persona with only its highest role. If only the Author may delete a post, a Copy Editor who wrote the post gets a different answer to one who didn't, so it needs its own scenario. For publishing, it doesn't: neither Copy Editor may publish. Put a persona with more than one role in the group of its highest role, straight after the persona with only that role.

Only add a persona when the app gets a new role. Don't add one to fill out a spec.

Personas make it easier to see which scenarios need covering. For each action, ask what each persona should be able to do, and on which records. The Guest and the User often show the gaps: an action left open by mistake, or one that anyone who signs in can use. A persona who may act, but not on this record, finds the rest, e.g. a User editing a post someone else wrote.

### Keep the ranks

List personas in rank order everywhere they appear, e.g. in the table above and in permission checks. Then every list of personas reads the same way, and a missing persona stands out.

```ruby
module Posts
  class PublicationPolicy < ApplicationPolicy
    def create?
      user.app_admin? || user.publishing_manager?
    end
  end
end
```

### Personas in specs

See [Testing: Principles](../../testing/principles/).
