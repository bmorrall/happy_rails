---
applyTo: "app/models/**/*.rb,app/actions/**/*.rb,app/forms/**/*.rb,app/controllers/**/*.rb,app/jobs/**/*.rb"
---

# AASM

- Put `include AASM` and the `aasm` block at the top of the model, under `### Modules (AASM) ###` and before `### Scopes ###`, with a comment saying why, on one line, e.g. `# AASM must come first: the model can override its scopes and constants`.
- Store the AASM state in a string column, e.g. `aasm column: :status` with a `string` `status` column. You MUST NOT declare an enum for the state column, e.g. `enum :status, { draft: "draft", published: "published" }`.
- Call an AASM event only from an action in the resource's module, e.g. `post.publish!` in `Posts::PublishPost`. You MUST NOT call an event anywhere else, e.g. in a controller, a form, a job, a model method or another resource's action. Checking an event or a state is fine anywhere, e.g. `post.may_publish?` or `post.published?`.
- Set `whiny_persistence: true` on every `aasm` block, e.g. `aasm column: :status, whiny_persistence: true do`, so a bang event raises when the record fails to save.
- In an action that calls an AASM event, rescue `AASM::InvalidTransition` and `ActiveRecord::RecordInvalid`, and raise them again as the action's `Error`, e.g. `rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e` then `raise Error, e.message` in `Posts::PublishPost#call`.
