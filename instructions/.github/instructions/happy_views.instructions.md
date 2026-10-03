---
applyTo: "app/views/**/*,app/helpers/**/*.rb,app/javascript/**/*"
---

# Views and frontend

- Keep templates and partials simple. Only output values, render other parts of the page, and use at most a simple `if` to show or hide part of it, or an `each` to repeat part of it for a list, e.g. `@posts.each`. Move anything more, e.g. choosing between values or formatting them, into a component, a decorator or a helper, e.g. `post_status(@post)` in `PostsHelper` instead of an `if @post.published?` with formatted dates in `app/views/posts/show.html.erb`.
- When you render a partial, pass every value it uses as a named local, e.g. `render "posts/byline", post: @post`. Never read an instance variable in a partial, e.g. `@post` in `app/views/posts/_byline.html.erb`.
- Format primitive values, e.g. dates, times and booleans, with one helper for each kind of value, and use the same helper everywhere the value is shown, including other helpers, decorators and components, e.g. `datetime_tag(@post.updated_at)` and `yes_no_tag(@post.featured?)`. Never format the value in place, e.g. `@post.updated_at.strftime("%d/%m/%Y")` or `@post.featured? ? "Yes" : "No"`.
- Avoid putting helpers in `ApplicationHelper`. Group related helpers in their own helper file. Name each file `<Things>Helper` after what it covers, in the plural, like the `PostsHelper` Rails generates for a resource, e.g. `date_tag` and `datetime_tag` in `app/helpers/dates_helper.rb`, and `yes_no_tag` in `app/helpers/booleans_helper.rb`.
- Prefer to show a value that is not known, e.g. `nil`, with an `unknown_value_tag` helper in `app/helpers/unknown_values_helper.rb`, and return it from helper and decorator methods that show a value that can be `nil`, instead of a blank, a dash or "N/A" written in place. If the app already shows missing values another way, follow it. Give the tag an `aria-label`, e.g. `tag.span("—", class: "text-muted", aria: { label: "Unknown" })`.
- Never write a view spec in `spec/views`. Cover branches in templates and partials with request specs, components with component specs, decorators with decorator specs, and helpers with helper specs.
- TODO: How to build forms.
- TODO: When to use Turbo Frames, Turbo Streams and Stimulus.
- TODO: CSS conventions.
