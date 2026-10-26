---
applyTo: "spec/**/*.rb"
---

# WebMock and VCR

- Stub HTTP requests with `stub_request` only inside a service's helpers in `spec/support`, and return the WebMock stub, e.g. `stub_newsletter_create` in `NewsletterServiceHelpers`.
- Inside a helper, stub an error with `.to_return(status: 500)` and a timeout with `.to_timeout`, e.g. `stub_request(:post, "https://newsletter.example.com/posts").to_timeout` in `stub_newsletter_create_timeout`.
- Check a stub a spec kept with `have_been_requested`, e.g. `expect(newsletter_request).to have_been_requested`.
- Write a `have_requested_` matcher as a method that returns WebMock's `have_requested` matcher and passes its keywords to `with` only when there are any, because `with` raises an error when called with no options, and use it on `WebMock`, e.g. `matcher = have_requested(:post, "https://newsletter.example.com/posts")` then `options.any? ? matcher.with(**options) : matcher` in `have_requested_newsletter_create(**options)`.
- TODO: How to record and replay HTTP requests with VCR.
