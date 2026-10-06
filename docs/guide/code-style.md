---
title: Code Style
parent: The Guide
nav_order: 13
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

## For agents

> **TODO:** Describe how you handle this.
