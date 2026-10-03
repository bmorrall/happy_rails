---
applyTo: "spec/**/*.rb"
---

# RSpec and FactoryBot

- TODO: Which spec types to write, and when.
- TODO: Where to put specs and how to name them.
- TODO: How to write factories, e.g. `create(:post)`.
- TODO: When to use traits.
- Write one `context` per persona in rank order, named after its role as `"as a <persona>"`, e.g. `context "as a user"`. Put the Guest last, as `context "when not signed in"`. Use `"as a"` only for persona contexts, e.g. `context "with a Turbo Stream"`, not `"as a Turbo Stream"`.
- For a persona with more than one role, name each role, highest first, e.g. `"as a <role> as the <record role>"`.
- Set up each persona inside its context as a signed-in `user`. Define `user` and the records the persona needs in each context, never in the `describe` block above. Never define a `let` per persona, e.g. `let(:<role>)`.
- For a role or flag on the whole app, build the user with a factory trait, e.g. `let(:user) { create(:user, :<role>) }`. Give the user factory one trait for each, named after it and defined in rank order. Use a plain `create(:user)` for the User persona, who has no role.
- Do not add a user trait for a role on one record. Build a plain `create(:user)` and give it the role on the record, e.g. as the record's owner or through a membership. For a persona with more than one role, build the user with the trait for the whole-app role, then give it the role on the record.
- The user may have a person's name, e.g. Jane Tester, but the context name must still give its role.
- TODO: How to write request specs.
- TODO: How to write system specs.
