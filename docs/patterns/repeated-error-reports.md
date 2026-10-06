---
title: Repeated Error Reports
parent: Patterns
nav_order: 2
---

# Repeated Error Reports

How to stop one problem from filling your error reports.

When another service is down, every request and every job that calls it fails the same way. Each failure can send a report, e.g. with [`Honeybadger.notify`](../../guide/gems/honeybadger/#reporting-errors). A short outage can send hundreds of reports for one problem. They use up your quota, and they bury new errors that need attention.

These patterns send fewer reports for the same problem.

## Report when retries run out

A job that calls another service can retry with `retry_on`. Active Job rescues the error on each attempt and enqueues the job again, so a failed attempt sends no report. Only the last failure is reported: Active Job raises it again when the attempts run out, or passes it to the `retry_on` block.

```ruby
class NotifySubscribersJob < ApplicationJob
  retry_on NewsletterClient::Error, attempts: 5 do |job, error|
    post = job.arguments.first
    Honeybadger.notify(error, context: { post: post.to_honeybadger_context })
    post.update!(newsletter_status: :failed)
  end

  # ...
end
```

Each job then sends one report, not one for every attempt. This doesn't help when many jobs fail at once, or when the error happens in a request. See [Throttle with the cache](#throttle-with-the-cache) for that.

## Throttle with the cache

Report the error through an action that sends the first report, and skips the same error again for a while. `Rails.cache.write` with `unless_exist: true` only writes when the key isn't there yet, and returns `false` when it is. The key then marks the error as reported until it expires.

```ruby
class ReportThrottledError < ApplicationAction
  def initialize(error, context: {}, fingerprint: nil, expires_in: 1.hour)
    @error = error
    @context = context
    @fingerprint = fingerprint
    @expires_in = expires_in
  end

  def call
    return unless Rails.cache.write(cache_key, true, unless_exist: true, expires_in:)

    Honeybadger.notify(error, context:)
  end

  private

  attr_reader :error, :context, :fingerprint, :expires_in

  def cache_key
    ["report_throttled_error", error.class.name, fingerprint].compact.join("/")
  end
end
```

The action doesn't work on a resource, so it has no module. Call it wherever you would call `Honeybadger.notify`, e.g. in a `rescue_from` handler. Pass the context of each record the error affects, as for `Honeybadger.notify`. See [Honeybadger: Context](../../guide/gems/honeybadger/#context).

```ruby
def handle_send_newsletter_service(error)
  ReportThrottledError.call(error, context: { post: @post&.to_honeybadger_context })

  redirect_to post_path(@post),
    alert: "Newsletter could not be sent. Please try again later."
end
```

By default, the action throttles by the error's class: one `Posts::SendNewsletter::ServiceError` an hour, however many users press the button. Pass a fingerprint to throttle a smaller group, e.g. one report per post. The fingerprint only sets what the action throttles. It doesn't change how Honeybadger groups the reports.

```ruby
ReportThrottledError.call(
  error,
  context: { post: post.to_honeybadger_context },
  fingerprint: "post-#{post.id}"
)
```

Pass `expires_in:` to change how long the action skips the same error. The default is an hour. Use a shorter time for an error you want to hear about again soon, and a longer one for an error you can't fix quickly, e.g. a service that is down for the day.

```ruby
ReportThrottledError.call(error, expires_in: 1.day)
```

Some things to know:

- The skipped errors are never reported, so the report doesn't show how many times the error happened. Check your logs for that.
- The cache store must support `unless_exist:`, e.g. Redis, Memcached or the memory store. Check yours before you rely on it.
- If the cache is cleared, the next error is reported again. That is safe, just one extra report.
