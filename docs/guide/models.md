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

  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
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

> **TODO:** Describe how you handle this.

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

> **TODO:** Describe how you handle this.
