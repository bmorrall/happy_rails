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

A job should call an action too. It may call a service directly only when the job is the only place that does the task, e.g. `NotifySubscribersJob` calls `NewsletterClient#deliver`. Move the call into an action when a second caller needs it, as in [Actions: When to write an action](../actions/#when-to-write-an-action).

## Kinds of services

> **TODO:** Describe how you handle this.

## Errors

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
