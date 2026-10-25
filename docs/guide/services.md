---
title: Services
parent: The Guide
nav_order: 7
---

# Services

How service objects are written and called.

A service object gives the app a set of related operations, e.g. `NewsletterClient` talks to the outside newsletter service. Put services in `app/services/`, e.g. `NewsletterClient` in `app/services/newsletter_client.rb`.

## Method names

A service object has no `call` method. Give each public method a name that says what it does, e.g. `create_newsletter` and `deliver` on `NewsletterClient`. A service usually offers more than one operation, and the caller's code then reads as what it asks the service to do. `call` is for [actions](../actions/), which each do one task.

```ruby
class NewsletterClient
  def create_newsletter(title:, body:)
    # ...
  end

  def deliver(newsletter_id)
    # ...
  end
end
```

```ruby
response = NewsletterClient.new.create_newsletter(title: post.title, body: post.body)
```

### One request per method

Each public method makes one request to the other service. When one request needs the reply to another, let an [action](../actions/) link them: it calls the first method, and passes the reply on to the second, e.g. `Posts::SendNewsletter` creates the newsletter, then hands its ID on for delivery. You SHOULD NOT chain requests inside a service method.

Between the requests, the action can save what it has so far, e.g. the newsletter's ID on the post. If the delivery fails, a retry delivers the same newsletter, instead of creating a second one. The service stays simple: each method sends one message, and its errors come from one request.

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    # ...

    def call
      newsletter = NewsletterClient.new.create_public_newsletter(title: post.title, body: post.body)
      post.update!(newsletter_id: newsletter.id)
      NotifySubscribersJob.perform_later(post)
    end
  end
end
```

```ruby
# Don't do this
class NewsletterClient
  def create_and_deliver(title:, body:)
    newsletter = create_public_newsletter(title:, body:)
    deliver_newsletter(newsletter.id)
  end
end
```

A request that only serves another request MAY stay in the service, e.g. fetching an access token, or looking up the other service's own ID for one of yours. It only reads, so a retry can repeat it safely, and the app never keeps or uses its reply. A request that changes something in the other service, e.g. reserving a slot before booking it, goes through an action, even when the app doesn't keep its reply. Make a read-only request in a private method, so callers still make one call.

```ruby
class NewsletterClient
  def create_public_newsletter(title:, body:)
    list_id = find_list_id("Weekly digest")
    # ...
  end

  private

  def find_list_id(name)
    response = connection.get("#{api_path}/lists", name:)
    response.body["lists"].first["id"]
  end
end
```

When the app saves that reply, e.g. to skip the lookup next time, it is no longer only for the other request. Move it to an action, as above.

## Calling a service

Actions are the gateway to services for other systems. Forms, controllers and jobs call an action, and the action calls the service. The action then decides how its task uses the service, e.g. what happens when the service fails, and every caller gets the same behaviour. See [Actions](../actions/).

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    # ...

    def call
      response = NewsletterClient.new.create_newsletter(title: post.title, body: post.body)
      post.update!(newsletter_id: response.id)
    end
  end
end
```

A form or controller MAY call a service directly when it only reads a value and nothing changes, e.g. a controller that shows a newsletter's open rate from `NewsletterClient#fetch_stats`. Anything that changes data, in the app or in the other service, goes through an action. See [Patterns: Values from Actions](../../patterns/values-from-actions/).

A controller reads the value before the view renders. See [Controllers: Values from services](../controllers/#values-from-services).

A job calls an action too. It MAY call a service directly only when the job is the only place that does the task, e.g. `NotifySubscribersJob` calls `NewsletterClient#deliver`. Move the call into an action when a second caller needs it, as in [Actions: When to write an action](../actions/#when-to-write-an-action).

## Request bodies

A service sends only the part of the other service's API that the app uses. The API, or its gem, takes every value an endpoint accepts. A service method takes only the values its caller decides, and fills in the rest itself, e.g. from its settings, its options, a lookup or a fixed value. Two methods MAY send to the same endpoint with different values filled in, e.g. `create_public_newsletter` and `create_private_newsletter` both create a newsletter, each with its own visibility.

Take each value the caller decides as a keyword argument, e.g. `create_public_newsletter(title:, body:)`. The action reads the values from its records, and decides what to send, e.g. `title: post.title`.

```ruby
module Posts
  class SendPublicNewsletter < NewsletterAction
    # ...

    def call
      newsletter = NewsletterClient.new.create_public_newsletter(title: post.title, body: post.body)
      post.update!(newsletter_id: newsletter.id)
    end
  end
end
```

You SHOULD NOT pass a record to a method that makes a request. The service then doesn't depend on your records, and each caller chooses what it sends. A service that takes a record decides for every caller which of the record's values go out.

```ruby
# Don't do this
class ExampleClient
  def create_item(record)
    connection.post("/items", { name: record.name, owner_name: record.owner.name })
  end
end
```

{: .rant }
> This makes an action easier to call than the service under it, and that's on purpose. `Posts::SendPublicNewsletter.call(post)` takes the post. `NewsletterClient#create_public_newsletter` makes you pick out the title and body yourself. When you're in a rush, reach for the action. It already knows what to send, where to save the reply, and how to fail. The service is there for the action that needs something it doesn't do yet.

You MUST NOT make the caller pass a value the service can fill in itself, e.g. the API key, or the ID of the "Weekly digest" list. The caller only knows what it wants to send. The service knows what the other service needs.

Build the request body in the service, as a hash. The body's format belongs to the other service. When its API changes, only the service changes, and every action that calls it gets the new format.

When the body takes more than a line, build it in a private method on the service, named after what it builds, e.g. `newsletter_body`. Kept with the service, it's easy to find, and you delete it with the service. A class your app uses for its own work stays with the rest of your app's code, e.g. in `app/models/` or `app/serializers/`, even when a service sends it.

```ruby
class NewsletterClient
  def create_public_newsletter(title:, body:)
    response = connection.post("#{api_path}/newsletters", newsletter_body(title:, body:, visibility: "public"))
    # ...
  end

  def create_private_newsletter(title:, body:)
    response = connection.post("#{api_path}/newsletters", newsletter_body(title:, body:, visibility: "private"))
    # ...
  end

  private

  def newsletter_body(title:, body:, visibility:)
    {
      title:,
      body:,
      visibility:
    }
  end
end
```

You MUST NOT make the caller build the body, e.g. a hash with the other service's field names. The format would then spread to every caller.

### Request objects

Some requests take more values than keyword arguments can carry, e.g. a newsletter with a preheader, a send time, a reply-to address and tracking settings, which an editor fills in on a form. A service MAY then define a `Data` object for the request, at the top of the service. Keyword arguments stay the default.

Name the request after the operation it's for, e.g. `NewsletterClient::CreateNewsletterRequest`. Methods that do the same operation with different values filled in share it, e.g. `create_public_newsletter` and `create_private_newsletter` both take a `CreateNewsletterRequest`. An operation that takes other fields gets its own request, e.g. an `UpdateNewsletterRequest`. Use `Data`, not a `Struct`.

The request lists the values a caller can set, and nothing else. `Data` raises an `ArgumentError` when a value is missing, or when the caller passes one it doesn't have. A hash with an extra key then fails in the app, and never reaches the other service. The service turns the request into the body, and fills in the rest, as above.

```ruby
class NewsletterClient
  CreateNewsletterRequest = Data.define(
    :title,
    :body,
    :preheader,
    :send_at,
    :reply_to,
    :track_opens,
    :track_clicks
  )

  def create_public_newsletter(request)
    response = connection.post("#{api_path}/newsletters", newsletter_body(request, visibility: "public"))
    # ...
  end

  def create_private_newsletter(request)
    response = connection.post("#{api_path}/newsletters", newsletter_body(request, visibility: "private"))
    # ...
  end

  private

  def newsletter_body(request, visibility:)
    request.to_h.merge(visibility:)
  end
end
```

The caller builds the service's request, and names its class to do so.

```ruby
module Posts
  class SendPublicNewsletter < NewsletterAction
    # ...

    def call
      request = NewsletterClient::CreateNewsletterRequest.new(
        title: post.title,
        body: post.body,
        **settings
      )
      newsletter = NewsletterClient.new.create_public_newsletter(request)
      post.update!(newsletter_id: newsletter.id)
    end
  end
end
```

You MUST NOT make the caller build a request for the gem the service calls, e.g. a request class the gem defines. The caller then depends on the gem, and swapping it changes every caller.

## Replies

Return a reply the caller reads by its fields, e.g. `response.id`. You SHOULD NOT return a hash. A service MAY define a `Data` object for a reply, at the top of the service, named after what it holds, e.g. `NewsletterClient::Newsletter`. Several operations can return the same reply, e.g. creating a newsletter and fetching one. Use `Data`, not a `Struct`.

```ruby
class NewsletterClient
  Newsletter = Data.define(:id, :status)

  def create_newsletter(title:, body:)
    response = connection.post("#{api_path}/newsletters", newsletter_body(title:, body:))
    Newsletter.new(id: response.body["id"], status: response.body["status"])
  end

  # ...
end
```

You SHOULD NOT return the reply of a gem the service calls, e.g. the `Aws::S3::Types::PutObjectOutput` that `Aws::S3::Client#put_object` returns. Build the service's own reply from it, or return the one value the caller needs. Callers then never depend on the gem.

Code outside the service MUST NOT name the reply's class, e.g. `NewsletterClient::Newsletter` in an action. It reads the fields instead. The class can then change with the other service's API, and only the service changes. A caller has to name a [request's](#request-objects) class to build it, but it never needs the reply's.

```ruby
# Don't do this
response = NewsletterClient.new.create_newsletter(title: post.title, body: post.body)
post.update!(newsletter_id: response.id) if response.is_a?(NewsletterClient::Newsletter)
```

### Pages

When the other service returns its results a page at a time, read one page in each call. Take the cursor as a keyword argument, e.g. `list_newsletters(cursor: nil)`, and return it with the page, e.g. as `next_cursor`. The caller decides whether to read the next page.

The caller knows how many results it needs. A controller shows one page. A job can work through one page in each run, so a failure retries only that page, and it never holds every result at once. You SHOULD NOT read every page in the service.

```ruby
class SyncNewslettersJob < ApplicationJob
  def perform(cursor = nil)
    page = NewsletterClient.new.list_newsletters(cursor:)
    # ...

    return if page.next_cursor.nil?

    SyncNewslettersJob.perform_later(page.next_cursor)
  end
end
```

### Files for requests and replies

Define a service's requests and replies at the top of the service at first. When they crowd out its methods, a service MAY move each one into its own file, in a folder named after the service, e.g. `app/services/newsletter_client/create_newsletter_request.rb`. Zeitwerk loads `NewsletterClient::CreateNewsletterRequest` from it, so callers don't change. Errors stay in the service's file, as in [Errors](#errors).

```ruby
# app/services/newsletter_client/create_newsletter_request.rb
class NewsletterClient
  CreateNewsletterRequest = Data.define(
    :title,
    :body,
    :preheader,
    :send_at,
    :reply_to,
    :track_opens,
    :track_clicks
  )
end
```

You MUST NOT move them into `app/models/`. A request or reply takes its shape from the other service's API, not from the app's records. Kept in `app/services/`, everything for one service is in one place, and you delete it all together. In `app/models/`, a reply looks like a model the app can use, but code outside the service MUST NOT name it.

## Configuration

Read a service's settings, e.g. an API key, from `Rails.application.config.x`. Give each service its own namespace, named after it, e.g. `config.x.newsletter_client`. Rails keeps `config.x` for app settings, so your keys never clash with a setting from Rails or a gem.

Set the values in one place, e.g. `config/application.rb`, from credentials or `ENV`. The service reads only `config.x`, not `Rails.application.credentials` or `ENV`. Then there's one place to look for every setting the app has.

```ruby
# config/application.rb
config.x.newsletter_client.api_key = Rails.application.credentials.dig(:newsletter_client, :api_key)
config.x.newsletter_client.base_url = "https://newsletter.example.com"
```

Take each setting as a keyword argument to `initialize`, with the setting as its default. Callers then write `NewsletterClient.new`, and never pass the settings. The default is read each time the service is built, so a change to the config is always picked up. A spec can pass its own values instead of stubbing the config.

Read each required setting with a bang, e.g. `api_key!`. It raises a `KeyError` when the setting is missing or blank, e.g. `:api_key is blank`, as soon as the service is built. Without the bang, a missing setting is `nil`, and the service fails later with a less helpful error, e.g. a 401 from the other service. The bang only works inside a namespace, e.g. `config.x.newsletter_client.api_key!`. You MUST NOT put a setting straight on `config.x`, e.g. `config.x.newsletter_client_api_key`. Rails then returns an empty set of options for a missing key, not `nil`, and its bang never raises.

```ruby
class NewsletterClient
  def initialize(
    api_key: Rails.application.config.x.newsletter_client.api_key!,
    base_url: Rails.application.config.x.newsletter_client.base_url!
  )
    @api_key = api_key
    @base_url = base_url
  end

  # ...
end
```

### Options

Set the options a service gives its client or library inside the service, e.g. the JSON middleware on `NewsletterClient`'s Faraday connection, or the Commonmarker extensions `MarkdownRenderer` turns on. Keep them in a constant or a private method. Options are the values no caller needs to send: callers pass only what changes with each call. Every call then works the same way, and a change to the options happens in one place.

Keep options out of `config.x`. They are the same in every environment, so they aren't settings.

```ruby
class NewsletterClient
  # ...

  private

  def connection
    Faraday.new(url: @base_url) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.response :raise_error
    end
  end
end
```

```ruby
class MarkdownRenderer
  # ...

  def render_html(markdown)
    Commonmarker.to_html(markdown, options: OPTIONS)
  end
end
```

### Timeouts

Give every service a timeout, and set it in `config.x` like its other settings, e.g. `config.x.newsletter_client.timeout_seconds`. Pass it to the HTTP library, e.g. Faraday's `timeout`. Without it, Faraday waits for a reply as long as the other service takes. When the service keeps a connection pool, the timeouts are connection settings, so pass them to the pool, not to `initialize`. See [Patterns: Connection Pools](../../patterns/connection-pools/).

A service MAY take more than one timeout, when one step needs its own limit, e.g. `open_timeout_seconds` for opening the connection, and `read_timeout_seconds` for the reply. Name each one after what it limits, and end it with its unit.

Set the timeouts below the app's request timeout, e.g. 10 seconds under rack-timeout's 15. See [Tooling and CI: Request timeouts](../tooling/#request-timeouts). A request that calls a slow service then gets the service's own error, and the action handles it like any other failure. If the request timeout went first, it would raise `Rack::Timeout::RequestTimeoutException` instead, wherever the request happened to be, and the action couldn't handle it. When an action makes more than one request, keep their timeouts together below the limit.

```ruby
# config/application.rb
config.x.newsletter_client.timeout_seconds = 10
```

```ruby
class NewsletterClient
  def initialize(
    api_key: Rails.application.config.x.newsletter_client.api_key!,
    base_url: Rails.application.config.x.newsletter_client.base_url!,
    timeout_seconds: Rails.application.config.x.newsletter_client.timeout_seconds!
  )
    @api_key = api_key
    @base_url = base_url
    @timeout_seconds = timeout_seconds
  end

  # ...

  private

  def connection
    Faraday.new(url: @base_url, request: { timeout: @timeout_seconds }) do |faraday|
      # ...
    end
  end
end
```

### Optional services

Some apps run without a service, e.g. in development without a newsletter API key. Give the service a `configured?` class method, which checks its required settings without the bang. Code that can work without the service checks `configured?` first, and skips the work when it's `false`.

The service knows which settings it needs, so a new required setting changes `configured?` in the same file. You MUST NOT add a separate `enabled` setting. It can say the service is on while its API key is missing.

```ruby
class NewsletterClient
  def self.configured?
    config = Rails.application.config.x.newsletter_client
    config.api_key.present? && config.base_url.present?
  end

  # ...
end
```

```ruby
class NotifySubscribersJob < ApplicationJob
  def perform(post)
    return unless NewsletterClient.configured?

    NewsletterClient.new.deliver(post.newsletter_id)
  end
end
```

You MUST NOT rescue the `KeyError` to find out whether a service is set up. That uses an exception for normal flow, and hides a real missing setting where the service is required.

```ruby
# Don't do this
def perform(post)
  NewsletterClient.new.deliver(post.newsletter_id)
rescue KeyError
  nil
end
```

### Settings from a record

Some settings are saved on a record, e.g. the API key and base URL on a `NewsletterServiceIntegration`. Build the service from the record with a class method on the service, e.g. `NewsletterClient.for(integration)`. Name it `for`, or `for_` and what the settings come from, e.g. `for_integration`, when the service has more than one builder or `for` alone isn't clear. Pass the record's settings to `new` as keywords, and leave out the settings that are the same for every record. Those keep their `config.x` defaults.

Make each setting that comes from the record a required keyword, with no default. A record without the setting then raises an `ArgumentError` when the service is built.

```ruby
class NewsletterClient
  def self.for(integration)
    new(
      api_key: integration.api_key,
      base_url: integration.base_url
    )
  end

  def initialize(
    api_key:,
    base_url:,
    api_path: Rails.application.config.x.newsletter_client.api_path!
  )
    @api_key = api_key
    @base_url = base_url
    @api_path = api_path
  end

  # ...
end
```

Put the class method on the service, not a method on the record, e.g. `integration.client`. The service knows which settings it needs, so a new setting changes only the service. A method on the record would also hand a working client to any code that holds the record, e.g. a view, and skip the action. Pass the record to the action, and build the service there, e.g. `NewsletterClient.for(integration).create_newsletter(title: post.title, body: post.body)`.

Encrypt the secrets on the record, e.g. `encrypts :api_key`. See [Models: Secrets](../models/#secrets).

When a service keeps connections open, share them through a connection pool on the service, keyed on the connection settings. Take the pool as a required first argument to `initialize`, and build the service with a class method that finds the pool. Use `NewsletterClient.default` when every setting comes from `config.x`, and `NewsletterClient.for(integration)`, or e.g. `for_integration`, when the settings come from a record. The connection settings go only to the pool, and `initialize` takes the settings sent with each request, e.g. `new(pool_for(base_url: integration.base_url), api_key: integration.api_key)`. You MUST NOT let a pooled connection carry one set of credentials to a service built with another: send the credentials with each request, or include them in the key. See [Patterns: Connection Pools](../../patterns/connection-pools/).

## Kinds of services

Write a service for one of two kinds of work:

- **Another system.** The service talks to a system outside the app, e.g. `NewsletterClient` calls the newsletter service's HTTP API, and `PostBackupBucket` saves posts to S3 through `Aws::S3::Client`. Every section on this page applies to it.
- **The app's own work.** The service wraps a library the app uses, e.g. `MarkdownRenderer` turns Markdown into HTML and plain text with Commonmarker, and `PostPdf` builds a post's PDF with Prawn. It makes no requests, so the sections about requests, replies, pages, timeouts and gateways don't apply. [Method names](#method-names), [Configuration](#configuration), including [Options](#options), and [Errors](#errors) still do.

```ruby
class MarkdownRenderer
  # ...

  def render_html(markdown)
    Commonmarker.to_html(markdown, options: OPTIONS)
  end

  def render_text(markdown)
    # ...
  end
end
```

Write a service only to wrap another system or a library. A calculation on a record stays on its model, e.g. a post's word count. A task that changes data is an [action](../actions/).

You MUST NOT save or change the app's models in a service, of either kind, including a record passed to it. The service returns what it made, and the action that called it saves the result, e.g. `Posts::SendNewsletter` saves the newsletter's ID on the post. The action then decides what changes, and keeps the changes in its own transaction.

A service MAY write to the store it wraps, e.g. `PostBackupBucket` uploads posts to S3. This holds even when the store keeps its data in the app's database, e.g. an event store backed by Active Record. Those rows belong to the library, not to a model in `app/models/`.

When a view needs a value from a service for the app's own work, a helper calls the service, e.g. `markdown_tag` calls `MarkdownRenderer`. Templates and decorators call the helper. See [Views and Frontend: Helpers](../views/#helpers). [Calling a service](#calling-a-service) covers services for other systems.

## Errors

Give each service its own errors. Define an `Error` class inside the service. Callers then rescue the service's errors, not the errors of the HTTP library it happens to use.

Rescue the library's errors inside the service, and raise the service's error instead. Ruby keeps the library's error as the `cause`.

Give the error everything you'd want to know when the call fails: the request method and URL, the response status and the response body. The service is the only code that has them. With Honeybadger, the error adds them to the report with `to_honeybadger_context`. See [Honeybadger: Errors](../gems/honeybadger/#errors).

A service MAY raise a subclass of `Error` for a failure a caller handles on its own. Add one only when a caller needs it. Without it, the failure raises the service's `Error` like any other. Name the subclass after its failure, e.g.:

- `UnprocessableError` when the other service rejects the request, e.g. `Faraday::UnprocessableEntityError`. A form can show the reason to the user, as in [Actions: Error handling](../actions/#error-handling).
- `TimeoutError` when the HTTP library says the request timed out, e.g. `Faraday::TimeoutError`. A controller can answer with a 504, as in [Controllers and Routes: Other services failing](../controllers/#other-services-failing).
- `UnavailableError` when the other service can't be reached or is down, e.g. `Faraday::ConnectionFailed` or a 503 reply. A controller can answer with a 503, so the client tries again later.
- `RateLimitedError` when the other service says the app sent too many requests, e.g. `Faraday::TooManyRequestsError`. A job can retry it later. Give it the reply's `Retry-After` value, e.g. `retry_after:`, so the caller knows how long to wait.
- `UnauthorizedError` when the other service refuses the credentials, e.g. `Faraday::UnauthorizedError` or `Faraday::ForbiddenError`. A retry fails the same way, so a job can mark the `NewsletterServiceIntegration` as broken instead.
- `NotFoundError` when the other service doesn't have the resource, e.g. `Faraday::ResourceNotFound` for a newsletter deleted on its side. A job can clear the post's `newsletter_id` instead of failing.

Rescue the library's specific errors before its base error, because Ruby uses the first `rescue` that matches.

Define the error classes in the service's file, even when its requests and replies have their own files. The errors then sit next to the code that raises them, and a reader sees every failure the service can raise in one place.

```ruby
class NewsletterClient
  class Error < StandardError
    def initialize(message = nil, http_method: nil, url: nil, status: nil, body: nil)
      # ...
    end
  end

  class UnprocessableError < Error; end
  class TimeoutError < Error; end

  def create_newsletter(title:, body:)
    # ...
  rescue Faraday::UnprocessableEntityError => e
    raise UnprocessableError.new(e.message, **details_from(e))
  rescue Faraday::TimeoutError => e
    raise TimeoutError.new(e.message, **details_from(e))
  rescue Faraday::Error => e
    raise Error.new(e.message, **details_from(e))
  end
end
```

## Gateways

A service SHOULD call the other system through its gem, when it has one, e.g. `PostBackupBucket` calls `Aws::S3::Client`. When the other system has no gem, make the HTTP calls in the service, e.g. with Faraday in `NewsletterClient`. The service only sends the part of the API the app uses, so its HTTP code stays small.

You SHOULD NOT write a gateway: your own client for the whole API, in `lib/`. Write one only when the API has no gem, and either several services share it, or its HTTP code has outgrown the service. See [Patterns: APIs without a Gem](../../patterns/apis-without-a-gem/).

## Testing

See [Testing: Services](../../testing/services/).
