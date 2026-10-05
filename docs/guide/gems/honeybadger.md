---
title: Honeybadger
parent: Gems
grand_parent: The Guide
nav_order: 3
---

# Honeybadger

Error reporting with [Honeybadger](https://github.com/honeybadger-io/honeybadger-ruby).

## Setup

> **TODO:** Describe how you handle this.

## Reporting errors

Honeybadger reports every error the app doesn't rescue, so let those errors raise. You only report an error yourself when the app rescues it, e.g. in a `rescue_from` handler or a job's `rescue`. Once the app rescues an error, Honeybadger never sees it.

Report a rescued error with `Honeybadger.notify`, not `Rails.error.report`. Then the code says where the report goes. Pass the error itself, not a message, so the report keeps its backtrace and its `cause`.

```ruby
module Posts
  class NewslettersController < BaseController
    rescue_from Posts::SendNewsletter::ServiceError, with: :handle_send_newsletter_service

    # ...

    private

    def handle_send_newsletter_service(error)
      Honeybadger.notify(error, context: { post: @post&.to_honeybadger_context })
      redirect_to post_path(@post), alert: "Newsletter could not be sent. Please try again later."
    end
  end
end
```

A `rescue_from` handler gets the error as its argument when the method takes one. See [Controllers and Routes: Other services failing](../../controllers/#other-services-failing).

Reporting an error that the app handles as an expected outcome is optional, e.g. a form that rescues `Posts::SendNewsletter::RejectedError` and shows it to the user. Nothing needs fixing, so you don't have to report it. It helps most while you build a new integration: the reports show how the other service fails, and what it sends back. Once you know, you can stop reporting it. When you do report it, tag it as low priority, e.g. `tags: ["low_priority"]`, so you can filter it out from the errors that need fixing. Honeybadger splits tags on spaces and commas, so use an underscore.

```ruby
rescue Posts::SendNewsletter::RejectedError => e
  Honeybadger.notify(e, context: { post: post.to_honeybadger_context }, tags: ["low_priority"])
  errors.add(:base, "Newsletter was rejected. Check the post and try again.")
  false
```

When the same error keeps happening, e.g. while another service is down, see [Patterns: Repeated Error Reports](../../../patterns/repeated-error-reports/) for ways to send fewer reports.

## Context

Give each model that shows up in error reports a `to_honeybadger_context` method. It returns a hash of what would help you debug the record.

The method is there for Honeybadger, so put it in a `concerning :HoneybadgerContext` block under a `### Modules (Honeybadger) ###` heading, as for any other gem. See [Models: Layout](../../models/#layout). The heading then says why the method is there, so no one removes it as unused. Don't name the block `:Honeybadger`. It would define `Comment::Honeybadger`, and `Honeybadger.notify` in the model would then call that module, not the gem.

Keep the hash flat, with no nested hashes or arrays, and never loop over an association, e.g. `comments.map`. A flat hash is easy to read and search in a report. A loop can load hundreds of records while the app is already handling an error.

Only add what would help you debug, e.g. the record's ID, its status and the dates that drive its behaviour. Leave out everything else. A smaller hash is quicker to read, and holds less data you'd need to keep safe.

Use the record's own attribute names for its own keys, e.g. `id` and `locked`. For each association that helps, add a few identifiers under its name, e.g. `post_id` and `post_title`, not the whole record. Take the ID from the record's own foreign key, e.g. `post_id`, not from the association, e.g. `post.id`. The foreign key is already loaded, so it needs no query, and it is still there when the post is missing. Read the association's other attributes with `&.`, e.g. `post&.title`, so a missing post doesn't raise an error while the app is reporting one.

```ruby
class Comment < ApplicationRecord
  # ...

  ### Modules (Honeybadger) ###

  concerning :HoneybadgerContext do
    def to_honeybadger_context
      {
        id: id,
        locked: locked,
        created_at: created_at,
        post_id: post_id,
        post_title: post&.title
      }
    end
  end
end
```

When you report an error, pass the context of each record the error affects, under the record's name. Each record's keys then stay apart, and the report shows which records were involved. Use `&.`, because the error may happen before a record is loaded, e.g. in a `before_action`.

```ruby
def handle_create_comment_service(error)
  Honeybadger.notify(error, context: {
    post: @post&.to_honeybadger_context,
    comment: @comment&.to_honeybadger_context
  })

  # ...
end
```

### Errors

An error can carry context too. When an error defines `to_honeybadger_context`, Honeybadger adds its hash to the report. The context you pass to `Honeybadger.notify` wins when both use the same key.

An error from a client for another service is the most useful place for this. The client is the only code that has the request and the response, so give its error the details you'd want when the service fails.

```ruby
class NewsletterClient
  class Error < StandardError
    def initialize(message = nil, http_method: nil, url: nil, status: nil, body: nil)
      super(message)
      @http_method = http_method
      @url = url
      @status = status
      @body = body
    end

    def to_honeybadger_context
      {
        request_method: http_method,
        request_url: url,
        response_status: status,
        response_body: body&.truncate(1_000)
      }
    end

    private

    attr_reader :http_method, :url, :status, :body
  end
end
```

Keep the hash flat, and start the keys with `request_` and `response_`, so they don't clash with the records in the report's context. Never add the request or response headers. They hold API keys and tokens. Cut the body short, e.g. to 1,000 characters, so a large error page doesn't fill the report. Leave out the query string when the service takes a key in the URL.

Honeybadger only reads `to_honeybadger_context` from the error it reports, not from the error's `cause`. An action raises its own error with the client's error as the `cause`, e.g. `Posts::SendNewsletter::ServiceError`, so the details would be lost. Pass them on with a `HoneybadgerCauseContext` concern in `app/models/concerns/honeybadger_cause_context.rb`.

```ruby
module HoneybadgerCauseContext
  extend ActiveSupport::Concern

  def to_honeybadger_context
    cause.respond_to?(:to_honeybadger_context) ? cause.to_honeybadger_context : {}
  end
end
```

Include it in the highest error class that an action raises in place of another error. That is usually the action's own `Error`, and the error classes for each cause inherit it from there. Don't include it in them again. See [Actions: Error handling](../../actions/#error-handling).

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    class Error < StandardError
      include HoneybadgerCauseContext
    end

    class RejectedError < Error; end
    class ServiceError < Error; end

    # ...
  end
end
```

## Filtering sensitive data

> **TODO:** Describe how you handle this.

## Jobs

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
