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
  def create_newsletter(post)
    # ...
  end

  def deliver(post)
    # ...
  end
end
```

```ruby
response = NewsletterClient.new.create_newsletter(post)
```

### One request per method

Each public method makes one request to the other service. When one request needs the reply to another, let an [action](../actions/) link them: it calls the first method, and passes the reply on to the second, e.g. `Posts::SendNewsletter` creates the newsletter, then hands its ID on for delivery. You SHOULD NOT chain requests inside a service method.

Between the requests, the action can save what it has so far, e.g. the newsletter's ID on the post. If the delivery fails, a retry delivers the same newsletter, instead of creating a second one. The service stays simple: each method sends one message, and its errors come from one request.

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    # ...

    def call
      newsletter = NewsletterClient.new.create_public_newsletter(post)
      post.update!(newsletter_id: newsletter.id)
      NotifySubscribersJob.perform_later(post)
    end
  end
end
```

```ruby
# Don't do this
class NewsletterClient
  def create_and_deliver(post)
    newsletter = create_public_newsletter(post)
    deliver_newsletter(newsletter.id)
  end
end
```

A request that only serves another request MAY stay in the service, e.g. fetching an access token, or looking up the other service's own ID for one of yours. It only reads, so a retry can repeat it safely, and the app never keeps or uses its reply. A request that changes something in the other service, e.g. reserving a slot before booking it, goes through an action, even when the app doesn't keep its reply. Make a read-only request in a private method, so callers still make one call. When you move the HTTP calls into a [gateway](#gateways), it moves to the gateway.

```ruby
class NewsletterClient
  def create_public_newsletter(post)
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

Actions are the gateway to services. Forms, controllers and jobs call an action, and the action calls the service. The action then decides how its task uses the service, e.g. what happens when the service fails, and every caller gets the same behaviour. See [Actions](../actions/).

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    # ...

    def call
      response = NewsletterClient.new.create_newsletter(post)
      post.update!(newsletter_id: response.id)
    end
  end
end
```

A form or controller MAY call a service directly when it only reads a value and nothing changes, e.g. a controller that shows a newsletter's open rate from `NewsletterClient#fetch_stats`. Anything that changes data, in the app or in the other service, goes through an action. See [Patterns: Values from Actions](../../patterns/values-from-actions/).

A controller reads the value before the view renders. See [Controllers: Values from services](../controllers/#values-from-services).

A job calls an action too. It MAY call a service directly only when the job is the only place that does the task, e.g. `NotifySubscribersJob` calls `NewsletterClient#deliver`. Move the call into an action when a second caller needs it, as in [Actions: When to write an action](../actions/#when-to-write-an-action).

## Request bodies

Build the request body in the service. Take records as arguments, e.g. `create_newsletter(post)`, and turn them into the body the other service expects.

The body's format belongs to the other service. When its API changes, only the service changes, and every action that calls it gets the new format.

Build the body as a hash. When it takes more than a line, build it in a private method on the service, named after what it builds, e.g. `newsletter_body(post)`. Kept with the service, it's easy to find, and you delete it with the service. A class your app uses for its own work stays with the rest of your app's code, e.g. in `app/models/` or `app/serializers/`, even when a service sends it.

```ruby
class NewsletterClient
  def create_newsletter(post)
    # ...
    connection.post("#{api_path}/newsletters", newsletter_body(post))
  end

  private

  def newsletter_body(post)
    {
      title: post.title,
      body: post.body,
      author_name: post.author.name
    }
  end
end
```

You SHOULD NOT define a `Data` object for the body in a service. A request object describes what a [gateway](#gateways) takes, and the gateway defines it. When you move the HTTP calls into a gateway, the private method builds the gateway's request instead of a hash, and nothing else in the service is renamed.

You MUST NOT make the caller build the request. Pass a value the service can't read from the record as a keyword argument instead. A [gateway](#gateways) is the one exception: the service builds the request and passes it to the gateway, as a hash or as a `Data` object the gateway defines.

```ruby
# Don't do this
class NewsletterClient
  def create_newsletter(request)
    # ...
  end
end
```

## Replies

Return a reply the caller reads by its fields, e.g. `response.id`. You SHOULD NOT return a hash. A service MAY define a `Data` object for a reply, at the top of the service, named after what it holds, e.g. `NewsletterClient::Newsletter`. Use `Data`, not a `Struct`.

```ruby
class NewsletterClient
  Newsletter = Data.define(:id, :status)

  def create_newsletter(post)
    response = connection.post("#{api_path}/newsletters", newsletter_body(post))
    Newsletter.new(id: response.body["id"], status: response.body["status"])
  end

  # ...
end
```

When you move the HTTP calls into a [gateway](#gateways), the reply moves to the gateway, e.g. `NewsletterGateway::Newsletter`. The service MAY then return the gateway's reply as it is. It holds only plain values, so a copy in the service would add nothing.

Code outside the service MUST NOT name the reply's class, e.g. `NewsletterGateway::Newsletter` in an action. It reads the fields instead. The class can then move to the gateway, or change with the other service's API, and only the service changes.

```ruby
# Don't do this
response = NewsletterClient.new.create_newsletter(post)
post.update!(newsletter_id: response.id) if response.is_a?(NewsletterGateway::Newsletter)
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

    NewsletterClient.new.deliver(post)
  end
end
```

You MUST NOT rescue the `KeyError` to find out whether a service is set up. That uses an exception for normal flow, and hides a real missing setting where the service is required.

```ruby
# Don't do this
def perform(post)
  NewsletterClient.new.deliver(post)
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

Put the class method on the service, not a method on the record, e.g. `integration.client`. The service knows which settings it needs, so a new setting changes only the service. A method on the record would also hand a working client to any code that holds the record, e.g. a view, and skip the action. Pass the record to the action, and build the service there, e.g. `NewsletterClient.for(integration).create_newsletter(post)`.

Encrypt the secrets on the record, e.g. `encrypts :api_key`. See [Models: Secrets](../models/#secrets).

When a service keeps connections open, share them through a connection pool on the service, keyed on the connection settings. Take the pool as a required first argument to `initialize`, and build the service with a class method that finds the pool. Use `NewsletterClient.default` when every setting comes from `config.x`, and `NewsletterClient.for(integration)`, or e.g. `for_integration`, when the settings come from a record. The connection settings go only to the pool, and `initialize` takes the settings sent with each request, e.g. `new(pool_for(base_url: integration.base_url), api_key: integration.api_key)`. You MUST NOT let a pooled connection carry one set of credentials to a service built with another: send the credentials with each request, or include them in the key. See [Patterns: Connection Pools](../../patterns/connection-pools/).

## Kinds of services

> **TODO:** Describe how you handle this.

## Errors

Give each service its own errors. Define an `Error` class inside the service, and a subclass for each failure a caller handles on its own, e.g. `NewsletterClient::UnprocessableError` when the newsletter service rejects a post. Callers then rescue the service's errors, not the errors of the HTTP library it happens to use.

Rescue the library's errors inside the service, and raise the service's error instead. Ruby keeps the library's error as the `cause`.

Give the error everything you'd want to know when the call fails: the request method and URL, the response status and the response body. The service is the only code that has them. With Honeybadger, the error adds them to the report with `to_honeybadger_context`. See [Honeybadger: Errors](../gems/honeybadger/#errors).

```ruby
class NewsletterClient
  class Error < StandardError
    def initialize(message = nil, http_method: nil, url: nil, status: nil, body: nil)
      # ...
    end
  end

  class UnprocessableError < Error; end

  def create_newsletter(post)
    # ...
  rescue Faraday::UnprocessableEntityError => e
    raise UnprocessableError.new(e.message, **details_from(e))
  rescue Faraday::Error => e
    raise Error.new(e.message, **details_from(e))
  end
end
```

## Gateways

Start with the HTTP calls in the service. When the service gets too big to read, move the code that talks to the other service's API into a gateway in `lib/`, e.g. `NewsletterGateway` in `lib/newsletter_gateway.rb`. The gateway does the mechanical work: the endpoints, headers, requests and replies. The service keeps the domain work: it takes records, builds the requests, and calls the gateway.

Write the gateway in plain Ruby. It takes and returns plain values, e.g. strings, arrays and hashes, and knows nothing about your records. You MUST NOT use Rails in a gateway, e.g. `Rails.application.config`, `Rails.logger`, credentials or `ENV`. You can then move it to a gem, or copy it to another app, as it is.

A gateway MAY also take and return `Data` objects that it defines itself, e.g. `NewsletterGateway::CreateNewsletterRequest` for a request and `NewsletterGateway::Newsletter` for the reply. Define them at the top of the gateway, so they move with it. Name a request after the gateway method that takes it, e.g. `create_newsletter` takes a `CreateNewsletterRequest`, because each call can send different fields. Name it after the gateway method, not the service method that builds it. Several service methods can call one gateway method, e.g. `create_public_newsletter` and `create_private_newsletter` on `NewsletterClient` both build a `CreateNewsletterRequest`, with a different `visibility`. Name a reply after what it holds, e.g. `Newsletter`, so more than one method can return it. The service MAY return the gateway's reply as it is. See [Replies](#replies). A `Data` object names the fields the API uses, can't be changed, and raises an error when a field is missing, or when the caller asks for one it doesn't have. Use `Data`, not a `Struct`.

The service builds the request from its records, as it would a hash. The gateway turns it into the body it sends, and builds the reply from the response.

```ruby
# lib/newsletter_gateway.rb
class NewsletterGateway
  CreateNewsletterRequest = Data.define(:title, :body, :visibility)
  Newsletter = Data.define(:id, :status)

  # ...

  def create_newsletter(request)
    response = connection.post("#{@api_path}/newsletters", request.to_h)
    Newsletter.new(id: response.body["id"], status: response.body["status"])
  end
end
```

```ruby
# app/services/newsletter_client.rb
class NewsletterClient
  # ...

  def create_public_newsletter(post)
    request = NewsletterGateway::CreateNewsletterRequest.new(title: post.title, body: post.body, visibility: "public")
    @gateway.create_newsletter(request)
  end

  def create_private_newsletter(post)
    request = NewsletterGateway::CreateNewsletterRequest.new(title: post.title, body: post.body, visibility: "private")
    @gateway.create_newsletter(request)
  end
end
```

A reply can hold more than the resource, e.g. a page of results with a cursor for the next page, or the request ID the other service gave the call. Return a response object then, named after the method, e.g. `list_newsletters` returns a `ListNewslettersResponse`. It holds the resources and the extra values. Each resource keeps its own object, e.g. `Newsletter`, which stays the same whichever method returns it. Like the service, the gateway reads one page in each call. See [Pages](#pages).

```ruby
# lib/newsletter_gateway.rb
class NewsletterGateway
  Newsletter = Data.define(:id, :status)
  ListNewslettersResponse = Data.define(:newsletters, :next_cursor)

  # ...

  def list_newsletters(cursor: nil)
    response = connection.get("#{@api_path}/newsletters", cursor:)
    newsletters = response.body["newsletters"].map do |item|
      Newsletter.new(id: item["id"], status: item["status"])
    end
    ListNewslettersResponse.new(newsletters:, next_cursor: response.body["next_cursor"])
  end
end
```

Take every setting as a keyword argument to `initialize`, with no default. The service reads the settings from `config.x`, as in [Configuration](#configuration), and passes them to the gateway.

```ruby
# lib/newsletter_gateway.rb
class NewsletterGateway
  def initialize(api_key:, base_url:, api_path:)
    @api_key = api_key
    @base_url = base_url
    @api_path = api_path
  end

  # ...
end
```

```ruby
# app/services/newsletter_client.rb
class NewsletterClient
  def initialize(
    api_key: Rails.application.config.x.newsletter_client.api_key!,
    base_url: Rails.application.config.x.newsletter_client.base_url!,
    api_path: Rails.application.config.x.newsletter_client.api_path!
  )
    @gateway = NewsletterGateway.new(api_key:, base_url:, api_path:)
  end

  # ...
end
```

Write one gateway for each outside API. When more than one service uses the same API, they share its gateway.

Give the gateway its own errors, with the details of the failed call, as in [Errors](#errors). The service rescues them like any library's errors, and raises its own errors with the same details. Callers then still rescue only the service's errors, e.g. `NewsletterClient::Error`.

Rails loads `lib/` with `config.autoload_lib`, the default in new apps since Rails 7.1.

## Testing

See [Testing: Services](../../testing/services/).
