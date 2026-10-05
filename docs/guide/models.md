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

  scope :recent, -> { order(created_at: :desc) }

  ### Constants ###

  TITLE_MAX_LENGTH = 100

  ### Attributes ###

  attribute :featured, :boolean, default: false

  ### Enumerations ###

  enum :status, { draft: 0, published: 1 }

  ### Associations ###

  belongs_to :author, class_name: "User"
  has_many :comments, dependent: :destroy

  ### Validations ###

  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }
  validate :published_at_cannot_be_in_the_future

  ### Callbacks ###

  before_save :set_published_at, if: :published?

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
    def publish!
      update!(status: :published)
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
validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }
```

> **TODO:** Describe how you handle the rest of this.

## Associations

> **TODO:** Describe how you handle this.

## Scopes and queries

> **TODO:** Describe how you handle this.

## Callbacks

> **TODO:** Describe how you handle this.

## Enums

> **TODO:** Describe how you handle this.

## Business logic

> **TODO:** Describe how you handle this.

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

Group the examples for a module in one `describe` block named after the module, e.g. `describe "FriendlyId"`, with a block for each of its methods inside.

Order the blocks in three tiers, each in alphabetical order:

1. Class methods and scopes, e.g. `describe ".recent"`
2. Instance methods, attributes and associations, e.g. `describe "#author"` and `describe "#published?"`
3. Modules, e.g. `describe "FriendlyId"`

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
    describe "#should_generate_new_friendly_id?" do
      it "is true when the title changes" do
        post = described_class.new(title: "A title")

        expect(post.should_generate_new_friendly_id?).to be(true)
      end
    end
  end
end
```

### Validations and associations

Test validations and associations with Shoulda Matchers. See [Shoulda Matchers: Validations](../gems/shoulda_matchers/#validations) and [Shoulda Matchers: Associations](../gems/shoulda_matchers/#associations).

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
  describe "#title" do
    it "is stripped when validated" do
      post = described_class.new(title: "  A title  ")

      post.validate

      expect(post.title).to eq("A title")
    end
  end
end
```

When a callback reaches outside the record, it doesn't change an attribute. Put its examples in the `describe` block of the method that triggers it, e.g. `describe "#save"` for an `after_create_commit` callback, or `describe "#destroy"` for an `after_destroy_commit` callback. Check the effect, e.g. that a job is enqueued. Don't name the block after the callback method. It is private, and the examples never call it.

```ruby
RSpec.describe Post do
  describe "#save" do
    it "enqueues a NotifySubscribersJob when a new post is saved" do
      post = build(:post)

      expect { post.save! }.to have_enqueued_job(NotifySubscribersJob).with(post)
    end
  end
end
```
