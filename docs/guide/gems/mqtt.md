---
title: MQTT
parent: Gems
grand_parent: The Guide
nav_order: 6
---

# MQTT

Sending and reading MQTT messages with the [mqtt](https://github.com/njh/ruby-mqtt) gem.

## Setup

> **TODO:** Describe how you handle this.

## Errors

Wrap the gem's errors in the service's own, as for any other service. See [Services](../../services/). `PostNotifier` rescues them and raises `PostNotifier::Error`.

Rescue `MQTT::Exception` by name. It inherits from `Exception`, not `StandardError`, so a bare `rescue => e` doesn't catch it. You MUST NOT rescue `Exception` to catch it, because that also catches `Interrupt` and `SystemExit`.

Rescue the socket's errors too, e.g. `Errno::ECONNREFUSED`, `Errno::EPIPE` and `SocketError`. The gem doesn't wrap them, so they reach the service as they are.

```ruby
class PostNotifier
  class Error < StandardError; end

  # ...

  def publish_post(post_id:, title:)
    pool.with do |client|
      client.publish("posts/#{post_id}/published", { title: }.to_json)
    end
  rescue MQTT::Exception, Errno::ECONNREFUSED, Errno::EPIPE, SocketError => e
    raise Error, e.message
  end
end
```

## Testing

See [Testing: MQTT](../../../testing/gems/mqtt/).
