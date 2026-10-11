---
title: Services
parent: Testing
nav_order: 7
---

# Services

How I test service objects.

For the code itself, see [Services](../../guide/services/).

## Service specs

> **TODO:** Describe how you handle this.

## Configuration

Pass a service its settings in specs, instead of stubbing `Rails.application.config.x`. The service takes each setting as a keyword argument, so the spec shows the values it uses, and no other spec sees them.

```ruby
RSpec.describe NewsletterClient do
  it "sends the API key with each request" do
    client = described_class.new(api_key: "test-key", base_url: "https://api.newsletter.test")

    # ...
  end
end
```

### Settings from a record

When the service takes a [connection pool](../../patterns/connection-pools/), pass a test pool as the first argument, e.g. `described_class.new(test_pool, api_key: "test-key")`. Only specs and the service's own class methods pass a pool to `new`.
