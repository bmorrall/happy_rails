---
applyTo: "app/services/**/*.rb"
---

# dry-rb

- A service MAY use a `Dry::Struct` for its request objects and replies, in place of `Data`, e.g. `class NewsletterClient::CreateNewsletterRequest < Dry::Struct`. Declare `schema schema.strict` on a request, so it raises when the caller passes a value it doesn't have.
- Declare a nested hash or array in a request or reply struct with a block on its attribute, without naming it, e.g. `attribute :tracking do ... end` in `NewsletterClient::CreateNewsletterRequest`. Pass plain hashes for nested values, e.g. `tracking: { opens: true, clicks: false }`.
- When a nested struct needs a name, e.g. two attributes share its shape, define its class inside the request or reply that uses it, e.g. a `Dry::Struct` class inside `NewsletterClient::CreateNewsletterRequest`, not inside `NewsletterClient`. You MUST NOT define it at the top of the service, or in `app/models/`.
- Use the app's `Types` module from `lib/types.rb` for every attribute type, e.g. `attribute :title, Types::String`. You MUST NOT define a types module in a service or struct, e.g. `NewsletterClient::Types`.
- TODO: How to use structs.
