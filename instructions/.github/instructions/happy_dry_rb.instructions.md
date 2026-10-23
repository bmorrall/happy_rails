---
applyTo: "app/services/**/*.rb"
---

# dry-rb

- A service MAY use a `Dry::Struct` for its request objects and replies, in place of `Data`, e.g. `class NewsletterClient::CreateNewsletterRequest < Dry::Struct`. Declare `schema schema.strict` on a request, so it raises when the caller passes a value it doesn't have.
- Use the app's `Types` module from `lib/types.rb` for every attribute type, e.g. `attribute :title, Types::String`. You MUST NOT define a types module in a service or struct, e.g. `NewsletterClient::Types`.
- TODO: How to use structs.
