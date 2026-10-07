---
title: Code Style
parent: The Guide
nav_order: 14
---

# Code Style

My own style preferences, on top of what RuboCop checks.
{: .fs-5 .fw-300 }

These are preferences, not Happy Rails conventions. Nothing else in the guide depends on them. If your app has its own style, skip this page and delete `happy_style.instructions.md`.

## Preferences

### Arguments to render and redirect_to

When a `render` or `redirect_to` call in a controller has more than one argument, put a newline after every comma. Indent each argument after the first on its own line. Then the status and the flash message each sit on their own line, and a diff that changes one of them touches only that line.

```ruby
def create
  @post = Post.new(post_params)

  if @post.save
    redirect_to @post,
      notice: "Post was created."
  else
    render :new,
      status: :unprocessable_entity
  end
end
```

The first argument stays on the line with `render` or `redirect_to`, because no comma comes before it. This is true even when it's a keyword argument, e.g. `json:`.

```ruby
render json: { error: "Newsletter could not be sent. Please try again later." },
  status: :bad_gateway
```

A call with one argument stays on one line, e.g. `redirect_to @post`.

Put a blank line above the call, or above its comment if it has one. Leave it out when the call is the first line in its block, e.g. straight after `if`, `else`, `def` or `do`. The blank line separates the work from the response, so you can see at a glance where the action ends.

```ruby
def create
  # ...

  Posts::SendNewsletter.call(@post)

  redirect_to post_path(@post),
    notice: "Newsletter was sent."
end
```

When the call is inside a `format` block, write the block with `do ... end`, not braces. The call now spans several lines, and braces are for one-line blocks.

```ruby
respond_to do |format|
  if @comment.save
    format.html do
      redirect_to @post,
        notice: "Comment was created."
    end
    format.turbo_stream
  else
    format.html do
      render :new,
        status: :unprocessable_entity
    end
  end
end
```

### Declarations

A declaration is a class-level call that sets up the class, e.g. `belongs_to`, `has_many`, `validates`, `before_action`, `rescue_from`, `delegate` or `attribute`. These rules apply to declarations in models, forms, actions, controllers, jobs and decorators. They don't apply to `include` or `extend`.

Keep the positional arguments on the first line, e.g. the attribute names in `validates` or the method names in `delegate`. Put each keyword argument on its own line, indented under the call. Then you can read a declaration's options as a list, and a diff that adds or changes one option touches only its line.

```ruby
class Post < ApplicationRecord
  scope :recent,
    -> { order(created_at: :desc) }

  belongs_to :author,
    class_name: "User"

  has_many :comments,
    dependent: :destroy

  has_many :approved_comments,
    -> { approved },
    class_name: "Comment",
    dependent: nil

  validates :title,
    presence: true,
    length: { maximum: TITLE_MAX_LENGTH, allow_blank: true }

  validate :published_at_cannot_be_in_the_future
end
```

This applies with one keyword argument too, e.g. `has_many :comments,` then `dependent: :destroy` on the next line. A lambda goes on its own line too, straight after the first line and before any keyword arguments, e.g. `scope :recent,` then `-> { order(created_at: :desc) }` on the next line. A long block is then easy to read, and the declaration's name stays on its own. A declaration with no keyword arguments or lambda stays on one line, e.g. `attribute :title, :string` or `validate :published_at_cannot_be_in_the_future`.

Put a blank line above and below each declaration, even one-line declarations next to each other, so each one reads as its own block. Leave out the line above when the declaration is the first line in its block, and the line below when it's the last line before `end`.

```ruby
class CreatePostForm < ApplicationForm
  attribute :title, :string

  attribute :status, :string

  normalizes :title,
    with: ->(title) { title.strip }
end
```

### Expectations

Build and assign values before `expect`, not inside its argument. Give each value its own line in the setup, then pass the variable to `expect`. Then the `expect` line only says what is checked, and each value has a name you can read.

```ruby
it "returns the unknown value tag for a draft" do
  post = instance_double(Post, published_at: nil)
  decorator = described_class.new(post)

  expect(decorator.published_on).to have_unknown_value_tag
end
```

Don't write `expect(described_class.new(post).published_on)` or `expect(post = create(:post))`. This doesn't apply to the block form, e.g. `expect { post posts_path }.to change(Post, :count).by(1)`, where the block is the action being checked.

## For agents

> **TODO:** Describe how you handle this.
