---
applyTo: "app/models/**/*.rb,spec/models/**/*.rb"
---

# Models

- Group model declarations under comment headings in this order: `### Scopes ###`, `### Constants ###`, `### Attributes ###`, `### Enumerations ###`, `### Associations ###`, `### Validations ###`, `### Callbacks ###`, `### Modules (GemName) ###`, `### Public Methods ###`. Leave out a group if the model has nothing in it.
- Name the gem in brackets in the modules heading, e.g. `### Modules (FriendlyId) ###` above `extend FriendlyId`.
- Give each gem its own modules heading, in alphabetical order unless one gem must be set up before another, e.g. `### Modules (Devise) ###` then `### Modules (FriendlyId) ###`.
- Put an `include` or `extend` at the top of the model only when a later declaration needs it, e.g. a macro it defines or a callback that must run first. Leave out the heading and add a comment saying what needs it, e.g. `# Sluggable must come before slug_from` above `include Sluggable`.
- Put shared logic in `concerning` blocks. Put a block that supports a gem's module under that module's heading, e.g. `concerning :Slugs` under `### Modules (FriendlyId) ###`. Put other blocks under `### Public Methods ###`, e.g. `concerning :Publishing`.
- Put private methods last, after `private`. Order them by the group they support, in the same order as the headings, e.g. a method for `validate :published_at_cannot_be_in_the_future` before a method for `before_save :set_published_at`.
- In model specs, build the record under test with `described_class.new` and only the attributes the example needs, e.g. `described_class.new(status: :published)` in `spec/models/post_spec.rb`. Do not use a factory for it.
- In model specs, name the `subject` after the model and use `is_expected` where possible, e.g. `subject(:post) { described_class.new }`. When an example needs a record with different attributes, build it in the example, e.g. `post = described_class.new(title: "A title")`, instead of adding a `let` or another `subject`.
- In model specs, group examples in a `describe` block named after the method, e.g. `describe "#published?"`. For an association, name the block after the association and put the examples for its id attribute in it too, e.g. `author_id` examples in `describe "#author"`.
- In model specs, group a module's examples in one `describe` block named after the module, with a block for each of its methods inside, e.g. `describe "FriendlyId"` containing `describe "#should_generate_new_friendly_id?"`.
- In model specs, order `describe` blocks in three tiers, each in alphabetical order: class methods and scopes, then instance methods, attributes and associations, then modules, e.g. `describe ".recent"`, then `describe "#author"` and `describe "#published?"`, then `describe "FriendlyId"`.
- In scope specs, create the records with factories and check the records the scope returns, e.g. `create(:post, created_at: 2.days.ago)` and `expect(described_class.recent).to eq([newer_post, older_post])`. Prefer this to comparing `to_sql`.
- Test a callback by what it does, through the call that triggers it, in the `describe` block of the attribute it changes. Say the trigger in the description, e.g. `it "is set when a published post is saved"` in `describe "#published_at"`. Never call the callback method directly or test that the callback is registered. When the callback has a condition, test both sides of it.
- Test a save callback by building the record with a factory and calling `save!`, e.g. `build(:post, status: :published, published_at: nil)` then `post.save!`. Test a validation callback by calling `validate` on a record built with `described_class.new`, e.g. `it "is set from the body when validated"` with `described_class.new(body: "word " * 400)` then `post.validate`.
- Test a normalisation in its attribute's `describe` block by building the record with the untidy value and reading it back, e.g. `it "is stripped"` with `expect(described_class.new(title: "  A title  ").title).to eq("A title")`. Never call `validate` or `save` for it.
- When a callback reaches outside the record, put its examples in the `describe` block of the method that triggers it and check the effect, e.g. `expect { post.save! }.to have_enqueued_job(NotifySubscribersJob).with(post)` in `describe "#save"` for an `after_create_commit` callback, or `describe "#destroy"` for an `after_destroy_commit` callback. Never name the block after the callback method.
- When an attribute has `presence: true`, add `allow_blank: true` to its other validators, so a blank value only gets "can't be blank", e.g. `validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }`.
- Tidy values with `normalizes` under `### Attributes ###`, e.g. `normalizes :isbn, with: ->(isbn) { isbn.delete("-") }`. Never tidy a value in a `before_validation` callback or an overridden writer, except before Rails 7.1, which has no `normalizes`: then use `before_validation { self.title = title&.strip }` under `### Callbacks ###`.
- In model specs, test an attribute that uses a custom validator with the validator's matcher, e.g. `it { is_expected.to validate_isbn_of(:isbn) }`. Never repeat the cases from the validator's own spec.
- TODO: How to write validations and associations.
- TODO: Where scopes and query logic go.
- TODO: When callbacks are allowed.
- TODO: Where business logic goes.
