---
applyTo: "config/honeybadger.yml,app/models/**/*.rb,app/actions/application_action.rb,app/controllers/**/*.rb,app/jobs/**/*.rb"
---

# Honeybadger

- TODO: How to set up Honeybadger.
- Let errors the app doesn't rescue raise, so Honeybadger reports them.
- Report an error the app rescues with `Honeybadger.notify`, never `Rails.error.report`, e.g. `Honeybadger.notify(error, context: { post: @post&.to_honeybadger_context })` in `handle_send_newsletter_service(error)` before the redirect.
- Pass the error itself to `Honeybadger.notify`, e.g. `Honeybadger.notify(error)`, not a message, e.g. `Honeybadger.notify(error.message)`.
- You may report an error that a form or a job handles as an expected outcome, e.g. `Honeybadger.notify(e, context: { post: post.to_honeybadger_context }, tags: ["low_priority"])` before `errors.add(:base, ...)` for `Posts::SendNewsletter::RejectedError`. It is optional, and most useful while building a new integration with another service. Always tag these reports `low_priority`.
- Give each model that shows up in error reports a `to_honeybadger_context` method that returns a hash of what helps debug the record, in a `concerning :HoneybadgerContext` block under a `### Modules (Honeybadger) ###` heading, e.g. in `Comment`. Never name the block `concerning :Honeybadger`, because it hides the gem's `Honeybadger` constant inside the model.
- Keep `to_honeybadger_context` flat, with no nested hashes or arrays, e.g. `post_id: post_id`, not `post: { id: post_id }`. Never loop over an association in it, e.g. `comments.map(&:id)`.
- Only add what helps with debugging to `to_honeybadger_context`, e.g. the record's ID, its status and the dates that drive its behaviour.
- Use the record's own attribute names for its own keys in `to_honeybadger_context`, e.g. `id: id` and `locked: locked`. For each association that helps, add a few identifiers under its name, e.g. `post_id: post_id` and `post_title: post&.title`, not the whole record. Take the ID from the record's own foreign key, e.g. `post_id: post_id`, never from the association, e.g. `post_id: post.id`. Read an association's other attributes with `&.`, e.g. `post&.title`, never `post.title`.
- When you report an error, pass the context of each record it affects under the record's name, with `&.`, e.g. `Honeybadger.notify(error, context: { post: @post&.to_honeybadger_context, comment: @comment&.to_honeybadger_context })`.
- Give a client's error for another service a `to_honeybadger_context` method with the request and response details, e.g. `request_method:`, `request_url:`, `response_status:` and `response_body: body&.truncate(1_000)` in `NewsletterClient::Error`.
- Keep an error's `to_honeybadger_context` flat, and start its keys with `request_` and `response_`. Never add request or response headers. Truncate the response body, e.g. `body&.truncate(1_000)`. Leave out the query string when the service takes a key in the URL.
- Pass on the cause's context from `ApplicationAction::Error`, e.g. `def to_honeybadger_context = cause.respond_to?(:to_honeybadger_context) ? cause.to_honeybadger_context : {}`, because Honeybadger never reads the context of an error's `cause`.
- TODO: How to keep sensitive data out of error reports.
- TODO: How to report errors from jobs.
- TODO: How to test error reporting.
