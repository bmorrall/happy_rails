---
applyTo: "app/models/**/*.rb,app/actions/**/*.rb,app/forms/**/*.rb,app/controllers/**/*.rb,app/jobs/**/*.rb,app/services/**/*.rb"
---

# Honeybadger

- Let errors the app doesn't rescue raise, so Honeybadger reports them.
- Call `Honeybadger.notify` only in controllers, forms, actions and jobs. You MUST NOT call it anywhere else, e.g. in a model or a service. Let the error raise to the code that handles it.
- Report an error the app rescues with `Honeybadger.notify`, not `Rails.error.report`, e.g. `Honeybadger.notify(error, context: { post: @post&.to_honeybadger_context })` in `handle_send_newsletter_service_error(error)` before the redirect.
- Pass the error itself to `Honeybadger.notify`, e.g. `Honeybadger.notify(error)`, not a message, e.g. `Honeybadger.notify(error.message)`.
- You MAY report an error that the app handles as an expected outcome, e.g. a form that rescues `Posts::SendNewsletter::RejectedError`. You SHOULD tag it `low_priority`, e.g. `Honeybadger.notify(e, context: { post: post&.to_honeybadger_context }, tags: ["low_priority"])`.
- Give each model that shows up in error reports a `to_honeybadger_context` method that returns a hash of what helps debug the record, in a `concerning :HoneybadgerContext` block under a `### Modules (Honeybadger) ###` heading, e.g. in `Comment`. You MUST NOT name the block `concerning :Honeybadger`.
- Keep `to_honeybadger_context` flat, with no nested hashes or arrays, e.g. `post_id: post_id`, not `post: { id: post_id }`. You MUST NOT loop over an association in it, e.g. `comments.map(&:id)`.
- Only add what helps with debugging to `to_honeybadger_context`, e.g. the record's ID, its status and the dates that drive its behaviour.
- Use the record's own attribute names for its own keys in `to_honeybadger_context`, e.g. `id: id` and `locked: locked`. For each association that helps, add a few identifiers under its name, e.g. `post_id: post_id` and `post_title: post&.title`, not the whole record. Take the ID from the record's own foreign key, e.g. `post_id: post_id`, not from the association, e.g. `post_id: post.id`. Read an association's other attributes with `&.`, e.g. `post&.title`, not `post.title`.
- When you report an error, pass the context of each record it affects under the record's name, with `&.`, e.g. `Honeybadger.notify(error, context: { post: @post&.to_honeybadger_context, comment: @comment&.to_honeybadger_context })`.
- In an error handling concern's handler, pass the context from a private method named after the handler, without `handle_` and with `_context` on the end, that returns an empty hash, e.g. `Honeybadger.notify(error, context: posts_newsletter_action_service_error_context)` in `handle_posts_newsletter_action_service_error(error)`, with `def posts_newsletter_action_service_error_context` returning `{}` in `PostsNewsletterActionErrorHandling`.
- In each controller that includes an error handling concern, you SHOULD override its context method to pass the context of the records the user was working on, e.g. `def posts_newsletter_action_service_error_context` returning `super.merge(post: @post&.to_honeybadger_context)` in `PostsController`.
- When you override a handler's context method, call `super` and merge the records into its hash, e.g. `super.merge(post: @post&.to_honeybadger_context)`.
- Give a client's error for another service a `to_honeybadger_context` method with the request and response details, e.g. `request_method:`, `request_url:`, `response_status:` and `response_body: body&.truncate(1_000)` in `NewsletterClient::Error`.
- Keep an error's `to_honeybadger_context` flat, and start its keys with `request_` and `response_`. You MUST NOT add request or response headers. Truncate the response body, e.g. `body&.truncate(1_000)`. Leave out the query string when the service takes a key in the URL.
- Pass on the cause's context by including the `HoneybadgerCauseContext` concern from `app/models/concerns/honeybadger_cause_context.rb` in the highest error class that an action raises in place of another error, usually the action's `Error`, e.g. `class Error < StandardError; include HoneybadgerCauseContext; end` in `Posts::SendNewsletter`. You MUST NOT include it again in the error classes for each cause, e.g. `ServiceError < Error`.
- TODO: How to keep sensitive data out of error reports.
- TODO: How to report errors from jobs.
