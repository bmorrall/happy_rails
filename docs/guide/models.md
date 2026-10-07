---
title: Models
parent: The Guide
nav_order: 3
---

# Models

How models are written and organised.

## Layout

Group the declarations in a model under comment headings, e.g. `### Attributes ###`, in this order:

1. Scopes
2. Constants
3. Attributes
4. Enumerations
5. Associations
6. Validations
7. Callbacks
8. Modules, with the name of the gem in brackets, e.g. `### Modules (FriendlyId) ###`
9. Public Methods

Every model then reads the same way, so you know where to look for a declaration and where to add a new one. Leave out a group if the model has nothing in it.

If a model uses more than one gem, give each gem its own Modules heading. Order them alphabetically, unless one gem depends on another being set up first.

Put an `include` or `extend` at the top of the model only when a later declaration needs it. For example, a later line might call a macro the module defines, or the module's callbacks might have to run before the model's own. It does not need a heading there. Add a comment saying what needs it instead. Without the comment, the next person may move it back down and break the model.

```ruby
class Post < ApplicationRecord
  # Sluggable must come before slug_from
  include Sluggable

  ### Attributes ###

  slug_from :title

  # ...
end
```

Put shared logic in `concerning` blocks. If the block supports a gem's module, put it under that module's heading. Put any other `concerning` block under Public Methods. Private methods go last, after `private`. Order them by the group they support, in the same order as the headings. For example, a validation method comes before a callback method.

```ruby
class Post < ApplicationRecord
  ### Scopes ###

  scope :recent,
    -> { order(created_at: :desc) }

  ### Constants ###

  TITLE_MAX_LENGTH = 100

  ### Attributes ###

  attribute :featured, :boolean,
    default: false

  ### Enumerations ###

  enum :status, { draft: 0, published: 1 }

  ### Associations ###

  belongs_to :author,
    class_name: "User"

  has_many :comments,
    dependent: :destroy

  ### Validations ###

  validates :title,
    presence: true,
    length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }

  validate :published_at_cannot_be_in_the_future

  ### Callbacks ###

  before_save :set_published_at,
    if: :published?

  ### Modules (FriendlyId) ###

  extend FriendlyId
  friendly_id :title, use: :slugged

  concerning :Slugs do
    def should_generate_new_friendly_id?
      title_changed?
    end
  end

  ### Public Methods ###

  concerning :Publishing do
    def recently_published?
      published? && published_at >= 1.week.ago
    end
  end

  private

  def published_at_cannot_be_in_the_future
    return if published_at.blank? || published_at <= Time.current

    errors.add(:published_at, "can't be in the future")
  end

  def set_published_at
    self.published_at ||= Time.current
  end
end
```

## Validations

When an attribute has `presence: true`, add `allow_blank: true` to its other validators. A blank value then gets one error, "can't be blank", not a stack of errors that all say it's missing. See [Validators: Blank values](../validators/#blank-values).

```ruby
validates :title,
  presence: true,
  length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }
```

### Normalising values

Tidy a value with `normalizes`, e.g. to strip spaces or remove hyphens. Put it under `### Attributes ###`. Rails runs it whenever the attribute is set, so validations always see the tidy value. It also runs on the values you pass to finders, e.g. `Post.find_by(isbn: "978-0306406157")` finds a post saved with `9780306406157`. Rails skips `nil`, so the block doesn't need `&.`.

```ruby
class Post < ApplicationRecord
  ### Attributes ###

  normalizes :title,
    with: ->(title) { title.strip }

  normalizes :isbn,
    with: ->(isbn) { isbn.delete("-") }

  # ...
end
```

Don't tidy a value in a `before_validation` callback, or by overriding its writer. A callback leaves the value untidy until the record is validated, and finders never use either of them. `normalizes` needs Rails 7.1 or later. Before that, tidy the value in a `before_validation` callback under `### Callbacks ###`, e.g. `before_validation { self.title = title&.strip }`.

> **TODO:** Describe how you handle the rest of this.

## Associations

Always pass `dependent:` to `has_many`. Rails leaves the associated records in place by default, and a missing option looks the same as a forgotten one. With the option on every `has_many`, each one shows a choice, and a reviewer can check what happens to the records when their parent is deleted.

Start with `dependent: :restrict_with_exception`. Deleting a record that still has associated records then raises an error, so nothing is deleted or left behind by accident. Change it once you've decided what should happen, e.g. `:destroy` when a post's comments should go with it. Write `dependent: nil` only when the records should stay, e.g. for a scoped association whose records another association already handles.

```ruby
class Post < ApplicationRecord
  ### Associations ###

  has_many :comments,
    dependent: :destroy

  has_many :approved_comments,
    -> { approved },
    class_name: "Comment",
    dependent: nil

  has_many :publications,
    dependent: :restrict_with_exception
end
```

`approved_comments` uses `dependent: nil` because `comments` already deletes the same records. A published post can't be deleted until you decide what happens to its publications.

> **TODO:** Describe how you handle the rest of this.

## Scopes and queries

> **TODO:** Describe how you handle this.

## Callbacks

A callback only changes the record's own attributes, e.g. setting `published_at` before a published post is saved. Never use a callback to create, change or delete another record, enqueue a job, send an email or call another service. This includes `after_commit` callbacks.

A callback runs on every save, wherever it comes from: a form, a job, the console, a seed file or a factory in a spec. Work in a callback that reaches outside the record runs in all of those places, even when the caller didn't want it. You also can't see it in the code that saves the record. Put that work in the form, action or job that does the task instead. The caller then shows everything that happens. See [Side Effects of Saving](../../patterns/side-effects-of-saving/) for where each kind of work goes.

```ruby
class Post < ApplicationRecord
  ### Callbacks ###

  before_save :set_published_at,
    if: :published?

  # ...

  private

  def set_published_at
    self.published_at ||= Time.current
  end
end
```

`dependent:` on an association is not a callback you write. It keeps the data consistent when a record is deleted, e.g. `has_many :comments, dependent: :destroy`, so use it as usual.

## Enums

> **TODO:** Describe how you handle this.

## Secrets

Encrypt a column that stores a secret, e.g. an API key or an access token, with `encrypts`. Put it under `### Attributes ###`. Rails encrypts the value before it saves it, so a database dump, a backup or a logged query doesn't show the secret. The model still reads it as plain text, e.g. `integration.api_key`.

```ruby
class NewsletterServiceIntegration < ApplicationRecord
  ### Attributes ###

  encrypts :api_key

  # ...
end
```

Active Record Encryption needs its keys before the first `encrypts`. Run `bin/rails db:encryption:init`, and add the keys it prints to the app's credentials.

## Business logic

A model never builds or calls a [service object](../services/). It changes and queries its own record. Work with another service goes in an action, which takes the record as an argument.

A method on the model that builds a service would let any code holding the record call the service, e.g. a view.

```ruby
class NewsletterServiceIntegration < ApplicationRecord
  # Don't do this
  def client
    NewsletterClient.for(self)
  end
end
```

> **TODO:** Describe how you handle the rest of this.

## Testing

### Building records

Build the record under test with `described_class.new`, not a factory. Pass only the attributes the example needs. The spec then shows everything the result depends on, and a change to a factory can't break it.

```ruby
RSpec.describe Post do
  describe "#published?" do
    it "is true for a published post" do
      post = described_class.new(status: :published)

      expect(post).to be_published
    end
  end
end
```

### Spec layout

Name the `subject` after the model, e.g. `subject(:post)`, and use `is_expected` where you can. When an example needs a record with different attributes, build it in the example, e.g. `post = described_class.new(title: "A title")`. Don't add a `let`, or another `subject`, for it. The example then shows the record it checks.

Group a model's examples in a `describe` block for each method, named after the method, e.g. `describe "#published?"`. For an association, name the block after the association, e.g. `describe "#author"`, and put the examples for its id attribute, e.g. `author_id`, in the same block. Everything about one method or association is then in one place.

Group the examples for each gem's Modules heading in one `describe` block named after the gem, e.g. `describe "FriendlyId"`. Put everything under that heading in it: what the gem's setup does, e.g. the slug it sets, and the methods of its `concerning` block, e.g. `#should_generate_new_friendly_id?`. The spec then matches the model, where both sit under `### Modules (FriendlyId) ###`. Don't add a `describe` block for the `concerning` block itself.

Group the examples for a `concerning` block under Public Methods in one `describe` block named after it, e.g. `describe "Publishing"` for `concerning :Publishing`. Put every method the block defines inside it, including scopes and class methods. Keep the examples in the model's spec. A `concerning` block lives in the model file, so its spec lives in the model's spec. If the examples outgrow the model's spec, move the code into its own file, e.g. a concern in `app/models/concerns`, and give that file its own spec.

Order the blocks in four tiers, each in alphabetical order:

1. Class methods and scopes, e.g. `describe ".recent"`
2. Instance methods, attributes and associations, e.g. `describe "#author"` and `describe "#published?"`
3. Modules, e.g. `describe "FriendlyId"`
4. Concerns, e.g. `describe "Publishing"`

Alphabetical order needs no judgement about which group a method belongs to, e.g. whether `published?` comes from an enum or a method. The tiers follow RSpec's prefixes: `.` for a class method and `#` for an instance method.

```ruby
RSpec.describe Post do
  subject(:post) { described_class.new }

  describe ".recent" do
    # ...
  end

  describe "#author" do
    it { is_expected.to belong_to(:author).class_name("User") }

    it "does not allow a banned user" do
      banned_user = create(:user, :banned)

      expect(post).not_to allow_value(banned_user.id).for(:author_id).with_message("can't be a banned user")
    end
  end

  describe "#published?" do
    # ...
  end

  describe "FriendlyId" do
    describe "#slug" do
      # ...
    end

    describe "#should_generate_new_friendly_id?" do
      it "is true when the title changes" do
        post = described_class.new(title: "A title")

        expect(post.should_generate_new_friendly_id?).to be(true)
      end
    end
  end

  describe "Publishing" do
    describe "#recently_published?" do
      # ...
    end
  end
end
```

### Validations and associations

Test validations and associations with Shoulda Matchers. See [Shoulda Matchers: Validations](../gems/shoulda_matchers/#validations) and [Shoulda Matchers: Associations](../gems/shoulda_matchers/#associations).

Test an attribute that uses a custom validator with the validator's matcher, e.g. `it { is_expected.to validate_isbn_of(:isbn) }`. Don't repeat the cases from the validator's own spec. See [Validators: Models and forms that use a validator](../validators/#models-and-forms-that-use-a-validator).

### Scopes

Scopes are an exception to building records with `described_class.new`. A scope queries the database, so its spec needs saved records. Create them with factories, and check the records the scope returns. Comparing the scope's `to_sql` with the query you expect also works, but a spec with records checks the result the scope is for.

```ruby
RSpec.describe Post do
  describe ".recent" do
    it "returns the newest post first" do
      older_post = create(:post, created_at: 2.days.ago)
      newer_post = create(:post, created_at: 1.day.ago)

      expect(described_class.recent).to eq([newer_post, older_post])
    end
  end
end
```

### Callbacks

Test a callback by what it does, through the call that triggers it in the app. Don't call the callback method itself, and don't test that the callback is registered. Put the examples in the `describe` block of the attribute the callback changes, and say in each description what triggers it, e.g. "when saved" or "when validated". When the callback has a condition, test both sides of it.

A save callback runs on `save`, which needs a valid record, so build the record with a factory, as for scopes.

```ruby
RSpec.describe Post do
  describe "#published_at" do
    it "is set when a published post is saved" do
      post = build(:post, status: :published, published_at: nil)

      freeze_time do
        post.save!

        expect(post.published_at).to eq(Time.current)
      end
    end

    it "is not set when a draft post is saved" do
      post = build(:post, status: :draft, published_at: nil)

      post.save!

      expect(post.published_at).to be_nil
    end
  end
end
```

A validation callback, e.g. `before_validation`, runs on `validate`. Call `validate` on a record built with `described_class.new`, so no factory is needed.

```ruby
RSpec.describe Post do
  describe "#reading_time" do
    it "is set from the body when validated" do
      post = described_class.new(body: "word " * 400)

      post.validate

      expect(post.reading_time).to eq(2)
    end
  end
end
```

Test a normalisation in the `describe` block of its attribute. Build the record with the untidy value, and read the attribute back. It runs when the attribute is set, so there's no need to call `validate` or `save`.

```ruby
RSpec.describe Post do
  describe "#title" do
    it "is stripped" do
      post = described_class.new(title: "  A title  ")

      expect(post.title).to eq("A title")
    end
  end
end
```
