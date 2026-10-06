---
applyTo: "app/controllers/**/*.rb"
---

# Code style

- When a `render` or `redirect_to` call in a controller has more than one argument, put a newline after every comma and indent each argument after the first on its own line, e.g. `redirect_to @post,` then `  notice: "Post was created."` on the next line. Keep the first argument on the line with `render` or `redirect_to`, even when it is a keyword argument, e.g. `render json: { error: "..." },` then `  status: :bad_gateway` on the next line. Keep a call with one argument on one line, e.g. `redirect_to @post`. When the call is inside a `format` block, write the block with `do ... end` instead of braces, e.g. `format.html do` instead of `format.html { redirect_to @post, notice: "Comment was created." }`.
- Put a blank line above a `render` or `redirect_to` call in a controller, or above its comment if it has one, e.g. between `Posts::SendNewsletter.call(@post)` and `redirect_to post_path(@post),`. Leave it out when the call is the first line in its block, e.g. straight after `if`, `else`, `def` or `do`.
- TODO: Agent-only style rules.
