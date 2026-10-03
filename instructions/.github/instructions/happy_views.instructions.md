---
applyTo: "app/views/**/*,app/helpers/**/*.rb,app/javascript/**/*"
---

# Views and frontend

- Keep templates and partials simple. Only output values, render other parts of the page, and use at most a simple `if` to show or hide part of it, or an `each` to repeat part of it for a list, e.g. `@posts.each`. Move anything more, e.g. choosing between values or formatting them, into a component, a decorator or a helper, e.g. `post_status(@post)` in `PostsHelper` instead of an `if @post.published?` with formatted dates in `app/views/posts/show.html.erb`.
- When you render a partial, pass every value it uses as a named local, e.g. `render "posts/byline", post: @post`. Never read an instance variable in a partial, e.g. `@post` in `app/views/posts/_byline.html.erb`.
- Never write a view spec in `spec/views`. Cover branches in templates and partials with request specs, components with component specs, decorators with decorator specs, and helpers with helper specs.
- TODO: When to write a helper.
- TODO: How to build forms.
- TODO: When to use Turbo Frames, Turbo Streams and Stimulus.
- TODO: CSS conventions.
