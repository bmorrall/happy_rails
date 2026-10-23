---
title: dry-rb
parent: Gems
grand_parent: The Guide
nav_order: 4
---

# dry-rb

Typed structs and values with the [dry-rb](https://dry-rb.org/) gems.

## Structs

> **TODO:** Describe how you handle this.

### Request and reply objects

A service MAY use a [dry-struct](https://dry-rb.org/gems/dry-struct/) for its [request objects](../../services/#request-objects) and [replies](../../services/#replies), in place of `Data`. It suits them well. Like `Data`, it raises when a value is missing. It also checks the type of each value, so a wrong value fails in the app, and never reaches the other service.

Declare `schema schema.strict` on a request, so it raises when the caller passes a value it doesn't have, as `Data` does.

```ruby
class NewsletterClient
  class CreateNewsletterRequest < Dry::Struct
    schema schema.strict

    attribute :title, Types::String
    attribute :body, Types::String
    attribute :send_at, Types::Time.optional
    attribute :track_opens, Types::Bool
  end

  # ...
end
```

## Types

Keep the app's types in one `Types` module, in `lib/types.rb`. Every struct then names its types the same way, e.g. `Types::String`, and the app has one place to add its own. Rails autoloads it with `config.autoload_lib`, which new apps call in `config/application.rb`.

```ruby
# lib/types.rb
module Types
  include Dry.Types()
end
```

You MUST NOT define a types module in a service or struct, e.g. `NewsletterClient::Types`.

## Testing

See [Testing: dry-rb](../../../testing/gems/dry_rb/).
