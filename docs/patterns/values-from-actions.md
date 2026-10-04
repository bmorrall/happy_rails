---
title: Values from Actions
parent: Patterns
nav_order: 1
---

# Values from Actions

How to get a value to the caller when [actions return nothing](../../guide/actions/#return-values).

Sometimes the caller needs a value that only exists after the action runs. For example, an action sends a post to a newsletter service, and the service replies with the newsletter's ID. An API client wants that ID, so it can track the newsletter.

The action can't return the ID. These patterns get it to the caller anyway.

## Clients return values, actions don't

A client for another service, e.g. `NewsletterClient`, is a request and reply object. It sends a request and returns the response, with no business logic. Returning a value is its whole job, so the no-return rule doesn't apply to it.

An action is a command. It changes something. If the caller only needs a value and nothing should change, call the client directly. Wrap the client in an action when there's work to do with the reply, e.g. saving it.

## Save the value on a record

Pass the action a record the caller already holds. The action saves the value on the record, and the caller reads it from there.

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    def initialize(post)
      @post = post
    end

    def call
      response = NewsletterClient.new.create_newsletter(post)
      post.update!(newsletter_id: response.id)
    end

    private

    attr_reader :post
  end
end
```

```ruby
# POST /api/v1/posts/:post_id/newsletter
def create
  # ...

  Posts::SendNewsletter.call(@post)
  render json: { newsletter_id: @post.newsletter_id }, status: :created
end
```

This works for most cases. The value usually belongs on a record anyway, because the app needs it again later. When the action creates a new record, the caller builds it first, e.g. with `Post.new`, and passes it in for the action to save. A form does the same: its `submit` returns the record, so the caller gets it from the form, not the action.

## Pass the ID in

When the other service accepts an ID from you, generate the ID in the caller and pass it to the action. The caller knows the ID before the action runs, so it doesn't need anything back.

```ruby
module Posts
  class SendNewsletter < ApplicationAction
    def initialize(post, newsletter_id:)
      @post = post
      @newsletter_id = newsletter_id
    end

    def call
      NewsletterClient.new.create_newsletter(post, id: newsletter_id)
    end

    private

    attr_reader :post, :newsletter_id
  end
end
```

```ruby
# POST /api/v1/posts/:post_id/newsletter
def create
  # ...

  newsletter_id = SecureRandom.uuid
  Posts::SendNewsletter.call(@post, newsletter_id:)
  render json: { newsletter_id: }, status: :created
end
```

## Give out your own ID

When an API client tracks a request, e.g. by a transaction ID, don't give the client the other service's ID. Create a record for the request first, with an ID of your own. Send your ID to the service as its reference, then save the service's ID on the record when it replies.

```ruby
class NewsletterDelivery < ApplicationRecord
  belongs_to :post
  has_secure_token :reference
end
```

```ruby
module NewsletterDeliveries
  class SendDelivery < ApplicationAction
    def initialize(delivery)
      @delivery = delivery
    end

    def call
      response = NewsletterClient.new.create_newsletter(delivery.post, reference: delivery.reference)
      delivery.update!(external_id: response.id, status: :sent)
    end

    private

    attr_reader :delivery
  end
end
```

```ruby
# POST /api/v1/posts/:post_id/newsletter_deliveries
def create
  # ...

  delivery = @post.newsletter_deliveries.create!
  NewsletterDeliveries::SendDelivery.call(delivery)
  render json: { reference: delivery.reference, status: delivery.status }, status: :created
end
```

When the service sends a webhook about the newsletter, find the record by the service's ID, e.g. `NewsletterDelivery.find_by!(external_id: params[:id])`, and update it. The API client sees the update under your reference.

Your own ID has some advantages:

- The client gets an ID even when the call to the service fails, or hasn't happened yet.
- The client never sees the other service's IDs. If you change services, the client doesn't notice.
- If the service accepts your reference as an idempotency key, you can retry the call safely, because the key doesn't change.

## Send it later

When the call to the service is slow or may fail, do it in a job. Create the record with your own ID, enqueue the job, and respond with `202 Accepted`. The client follows the request through your API, e.g. `GET /api/v1/newsletter_deliveries/:reference`, or waits for a webhook from your app.

```ruby
# POST /api/v1/posts/:post_id/newsletter_deliveries
def create
  # ...

  delivery = @post.newsletter_deliveries.create!
  SendNewsletterDeliveryJob.perform_later(delivery)
  render json: { reference: delivery.reference, status: delivery.status }, status: :accepted
end
```

The job calls `NewsletterDeliveries::SendDelivery`, so the action is the same as before. Only the time it runs changes.

## What to avoid

Don't pass the value back through a block, e.g. `Posts::SendNewsletter.call(post) { |newsletter_id| ... }`. It is a return value in disguise.

Don't return a result object, e.g. `Result.new(success: true, value: response.id)`. The caller then has to check the result, which is what the action's [custom `Error`](../../guide/actions/#error-handling) replaces.

If the value can't live on a record, and the caller can't get it straight from a client, the action is probably doing two things. Split it into a client call that returns the value and an action that does the work.
