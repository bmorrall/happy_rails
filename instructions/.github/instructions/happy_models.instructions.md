---
applyTo: "app/models/**/*.rb"
---

# Models

- Group model declarations under comment headings in this order: `### Scopes ###`, `### Constants ###`, `### Attributes ###`, `### Enumerations ###`, `### Associations ###`, `### Validations ###`, `### Callbacks ###`, `### Modules (GemName) ###`, `### Public Methods ###`. Leave out a group if the model has nothing in it.
- Name the gem in brackets in the modules heading, e.g. `### Modules (FriendlyId) ###` above `extend FriendlyId`.
- Give each gem its own modules heading, in alphabetical order unless one gem must be set up before another, e.g. `### Modules (Devise) ###` then `### Modules (FriendlyId) ###`.
- Put an `include` or `extend` at the top of the model only when a later declaration needs it, e.g. a macro it defines or a callback that must run first. Leave out the heading and add a comment saying what needs it, e.g. `# Sluggable must come before slug_from` above `include Sluggable`.
- Put shared logic in `concerning` blocks. Put a block that supports a gem's module under that module's heading, e.g. `concerning :Slugs` under `### Modules (FriendlyId) ###`. Put other blocks under `### Public Methods ###`, e.g. `concerning :Publishing`.
- Put private methods last, after `private`. Order them by the group they support, in the same order as the headings, e.g. a method for `validate :published_at_cannot_be_in_the_future` before a method for `before_save :set_published_at`.
- TODO: How to write validations and associations.
- TODO: Where scopes and query logic go.
- TODO: When callbacks are allowed.
- TODO: Where business logic goes.
- TODO: How to test models.
