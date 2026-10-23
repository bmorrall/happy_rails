---
title: APIs without a Gem
parent: Patterns
nav_order: 8
---

# APIs without a Gem

How to talk to another system's API when it has no gem, and the HTTP code no longer fits in one [service object](../../guide/services/).

A service usually calls the other system through its gem, e.g. `PostBackupBucket` calls `Aws::S3::Client`. The gem covers the whole API, and the service sends only the part the app uses. See [Services: Gateways](../../guide/services/#gateways).

Without a gem, the service makes the HTTP calls itself. That gets harder in two cases:

- Several services use the same API, and each one repeats its endpoints, headers and error handling.
- The service has grown too big to read, and its HTTP code hides what the app sends.

## HTTP calls in the service

Start here, and stay here while it's easy to read. The service only sends what the app uses, so its HTTP code stays small. The endpoints, the body and the reply all sit next to the method that uses them.

```ruby
class NewsletterClient
  Newsletter = Data.define(:id, :status)

  # ...

  def create_public_newsletter(title:, body:)
    response = connection.post("#{@api_path}/newsletters", { title:, body:, visibility: "public" })
    Newsletter.new(id: response.body["id"], status: response.body["status"])
  end

  private

  def connection
    Faraday.new(url: @base_url) do |faraday|
      # ...
    end
  end
end
```

This suits most services. Move to a gateway only when one of the cases above applies.

## A gateway in lib/

Write the gem the other system doesn't have: a gateway in `lib/`, e.g. `NewsletterGateway` in `lib/newsletter_gateway.rb`. The gateway covers the whole endpoint: every field it accepts, its headers, and its replies. The service keeps the part the app uses. It takes the values its caller decides, fills in the rest, and calls the gateway.

Write the gateway in plain Ruby. It takes and returns plain values, e.g. strings, arrays and hashes, and knows nothing about your records. Keep Rails out of it, e.g. `Rails.application.config`, `Rails.logger`, credentials and `ENV`. You can then move it to a gem, or copy it to another app, as it is.

Rails loads `lib/` with `config.autoload_lib`, the default in new apps since Rails 7.1.

### Requests and replies

A gateway can take and return `Data` objects that it defines itself, e.g. `NewsletterGateway::CreateNewsletterRequest` for a request and `NewsletterGateway::Newsletter` for the reply. Define them at the top of the gateway, so they move with it. Use `Data`, not a `Struct`.

Name a request after the gateway method that takes it, e.g. `create_newsletter` takes a `CreateNewsletterRequest`, because each endpoint takes different fields. It lists every field the endpoint accepts, including the ones the service fills in, e.g. `visibility`. Name a reply after what it holds, e.g. `Newsletter`, so more than one method can return it.

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

Several service methods can call one gateway method, each with its own values filled in. The service builds the gateway's request from what its caller passed, as it would build a hash.

```ruby
# app/services/newsletter_client.rb
class NewsletterClient
  # ...

  def create_public_newsletter(title:, body:)
    request = NewsletterGateway::CreateNewsletterRequest.new(title:, body:, visibility: "public")
    @gateway.create_newsletter(request)
  end

  def create_private_newsletter(title:, body:)
    request = NewsletterGateway::CreateNewsletterRequest.new(title:, body:, visibility: "private")
    @gateway.create_newsletter(request)
  end
end
```

When the service takes a [request object](../../guide/services/#request-objects) of its own, the two can share a name, e.g. `NewsletterClient::CreateNewsletterRequest` and `NewsletterGateway::CreateNewsletterRequest`. The service's request holds the values its callers can set. The gateway's holds every field the endpoint accepts. The service writes `NewsletterGateway::` in full when it builds the gateway's, so the two don't get mixed up. Callers only ever build the service's.

The service can return the gateway's reply as it is. You wrote it as plain `Data`, so a copy in the service would add nothing. Callers still don't name its class. See [Services: Replies](../../guide/services/#replies).

A reply can hold more than the resource, e.g. a page of results with a cursor for the next page, or the request ID the other service gave the call. Return a response object then, named after the method, e.g. `list_newsletters` returns a `ListNewslettersResponse`. It holds the resources and the extra values. Each resource keeps its own object, e.g. `Newsletter`, which stays the same whichever method returns it. Like the service, the gateway reads one page in each call. See [Services: Pages](../../guide/services/#pages).

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

### Settings

Take every setting as a keyword argument to `initialize`, with no default. The service reads the settings from `config.x`, as in [Services: Configuration](../../guide/services/#configuration), and passes them to the gateway.

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

### Errors

Give the gateway its own errors, with the details of the failed call, as in [Services: Errors](../../guide/services/#errors). The service rescues them like a gem's errors, and raises its own errors with the same details. Callers then still rescue only the service's errors, e.g. `NewsletterClient::Error`.

### Testing

Don't stub the gateway in the service's spec, e.g. with `instance_double(NewsletterGateway)`. Stub the requests with the service's helpers, as in [Testing: Services](../../testing/services/#service-specs). The spec then still checks the full message the service sends, through the gateway.
