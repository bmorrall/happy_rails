---
applyTo: "**"
---

# Rails conventions

This is a Rails app that follows the Happy Rails conventions:
https://bmorrall.github.io/happy_rails/

Follow these rules for all changes. Area-specific rules are in `.github/instructions/`.

## General

- TODO: State the guiding principles in short imperative sentences, e.g. "Prefer Rails defaults over extra gems."
- Match the style of the surrounding code.

## Personas

- Think of users as personas. A persona is a role that lets a user take certain actions on certain records. A role can apply to the whole app, e.g. a role or a flag on the user, or to one record the user is given, e.g. as the record's owner or through a membership.
- Use only the roles, groups and personas the app already has. Never add one that the task does not ask for.
- Treat a signed-in user with no role as the User persona, and a visitor who has not signed in as the Guest persona.
- Rank the app's persona groups from most access to least, with the Users group and then the Guest last. Personas inside each group also have a fixed rank. Take the ranks from the app, e.g. the order of persona contexts in its existing specs.
- Only add a persona with more than one role when it changes the outcome, compared with the persona with only its highest role.
- Put a persona with more than one role in the group of its highest role, straight after the persona with only that role.
- When you add or change an action, cover what each persona may do, and on which records. Include a persona who may act on some records but not this one, e.g. a user who did not create the record.
- In request and feature specs, do not cover a persona whose role plays no part in the action. The User persona covers it, and so does the policy spec.
- List personas in rank order everywhere: in permission checks, and in request and feature specs.

## Project layout

- Group the code for one feature in a concern when it could be shared with other classes or removed all at once later. Name the concern after what it does, and put it in `app/models/concerns/` or `app/controllers/concerns/`.
- When only one class uses the code, write it in a `concerning` block in that class instead of a separate concern file, e.g. `concerning :Publishing do` in `Post`, with the `published` scope and `publish` method inside it.
- Put every `include`, callback, error handler and helper a gem adds to a base class in one concern named after the gem's module, and include that concern in the base class, e.g. `PunditAuthorization` in `app/controllers/concerns/pundit_authorization.rb` with `include Pundit::Authorization`, `after_action :verify_authorized` and `rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized`, included in `ApplicationController`.
- TODO: List where each kind of code belongs.

## Before you finish

- TODO: List the commands an agent must run before it says a change is done, e.g. the linter.

## Testing

- TODO: How to test changes to the app.
