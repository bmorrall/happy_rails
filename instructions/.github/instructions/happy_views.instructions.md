---
applyTo: "app/views/**/*,app/helpers/**/*.rb,app/javascript/**/*"
---

# Views and frontend

- Keep templates and partials simple. Only output values, render other parts of the page, and use at most a simple `if` to show or hide part of it, or an `each` to repeat part of it for a list, e.g. `@posts.each`. Move anything more, e.g. choosing between values or formatting them, into a component, a decorator or a helper, e.g. `post_status(@post)` in `PostsHelper` instead of an `if @post.published?` with formatted dates in `app/views/posts/show.html.erb`.
- When you render a partial, pass every value it uses as a named local, e.g. `render "posts/byline", post: @post`. Never read an instance variable in a partial, e.g. `@post` in `app/views/posts/_byline.html.erb`.
- Set data attributes with the `data:` option of a tag helper, e.g. `tag.div` or `content_tag`, or of another helper, e.g. `link_to`, such as `tag.div data: { controller: "comments", comments_url_value: post_comments_path(@post) }` and `link_to "Show comments", post_comments_path(@post), data: { turbo_frame: "comments" }`. Never write a data attribute as HTML in a template, e.g. `<div data-controller="comments">`.
- Format primitive values, e.g. dates, times and booleans, with one helper for each kind of value, and use the same helper everywhere the value is shown, including other helpers, decorators and components, e.g. `datetime_tag(@post.updated_at)` and `yes_no_tag(@post.featured?)`. Never format the value in place, e.g. `@post.updated_at.strftime("%d/%m/%Y")` or `@post.featured? ? "Yes" : "No"`.
- Avoid putting helpers in `ApplicationHelper`. Group related helpers in their own helper file. Name each file `<Things>Helper` after what it covers, in the plural, like the `PostsHelper` Rails generates for a resource, e.g. `date_tag` and `datetime_tag` in `app/helpers/dates_helper.rb`, and `yes_no_tag` in `app/helpers/booleans_helper.rb`.
- Give each helper that builds a simple view element a matcher for specs, e.g. `have_unknown_value_tag` for `unknown_value_tag`. See `happy_rspec.instructions.md`.
- Prefer to show a value that is not known, e.g. `nil`, with the `unknown_value_tag` helper from `app/helpers/unknown_values_helper.rb`, and return it from helper and decorator methods that show a value that can be `nil`, instead of a blank, a dash or "N/A" written in place. If the app already shows missing values another way, follow it.
- Prefer to build forms with `form_with`, passing a model or a form object as `model:`, e.g. `form_with model: @post` or `form_with model: @create_post_form`. Avoid `form_for`, `form_tag`, and `form_with` with only a `url:` or a `scope:`, e.g. `form_with url: posts_path, scope: :post`. If the app uses Simple Form, use `simple_form_for` instead, in the same way.
- Never write a view spec in `spec/views`. Cover branches in templates and partials with request specs, components with component specs, decorators with decorator specs, and helpers with helper specs.
- TODO: When to use Turbo Frames, Turbo Streams and Stimulus.
- TODO: CSS conventions.
