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

A form or controller may call a service directly when it only reads a value and nothing changes, e.g. a controller that shows a newsletter's open rate from `NewsletterClient#fetch_stats`. Anything that changes data, in the app or in the other service, goes through an action. See [Patterns: Values from Actions](../../patterns/values-from-actions/).

A job should call an action too. It may call a service directly only when the job is the only place that does the task, e.g. `NotifySubscribersJob` calls `NewsletterClient#deliver`. Move the call into an action when a second caller needs it, as in [Actions: When to write an action](../actions/#when-to-write-an-action).

## Configuration

Read a service's settings, e.g. an API key, from `Rails.application.config.x`. Give each service its own namespace, named after it, e.g. `config.x.newsletter_client`. Rails keeps `config.x` for app settings, so your keys never clash with a setting from Rails or a gem.

Set the values in one place, e.g. `config/application.rb`, from credentials or `ENV`. The service reads only `config.x`, never `Rails.application.credentials` or `ENV`. Then there's one place to look for every setting the app has.

```ruby
# config/application.rb
config.x.newsletter_client.api_key = Rails.application.credentials.dig(:newsletter_client, :api_key)
config.x.newsletter_client.base_url = "https://api.newsletter.example"
```

Take each setting as a keyword argument to `initialize`, with the setting as its default. Callers then write `NewsletterClient.new`, and never pass the settings. The default is read each time the service is built, so a change to the config is always picked up. A spec can pass its own values instead of stubbing the config.

Read each required setting with a bang, e.g. `api_key!`. It raises a `KeyError` when the setting is missing or blank, e.g. `:api_key is blank`, as soon as the service is built. Without the bang, a missing setting is `nil`, and the service fails later with a less helpful error, e.g. a 401 from the other service. The bang only works inside a namespace, e.g. `config.x.newsletter_client.api_key!`. Never put a setting straight on `config.x`, e.g. `config.x.newsletter_client_api_key`. Rails then returns an empty set of options for a missing key, not `nil`, and its bang never raises.

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

### Settings from a record

Some settings are saved on a record, e.g. the API key and base URL on a `NewsletterServiceIntegration`. Build the service from the record with a class method on the service, e.g. `NewsletterClient.for(integration)`. `for` reads well, but any name that says where the settings come from works, e.g. `from_integration`. Pass the record's settings to `new` as keywords, and leave out the settings that are the same for every record. Those keep their `config.x` defaults.

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

When a service keeps connections open, share them through a connection pool on the service, keyed on the connection settings. Never let a pooled connection carry one set of credentials to a service built with another: send the credentials with each request, or include them in the key. See [Patterns: Connection Pools](../../patterns/connection-pools/).

## Kinds of services

> **TODO:** Describe how you handle this.

## Errors

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
