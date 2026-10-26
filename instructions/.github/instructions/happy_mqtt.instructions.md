---
applyTo: "app/services/**/*.rb"
---

# MQTT

- Rescue `MQTT::Exception` by name in the service and raise the service's own error, e.g. `rescue MQTT::Exception => e` then `raise Error, e.message` in `PostNotifier`, because it inherits from `Exception`, not `StandardError`, so a bare `rescue => e` misses it. You MUST NOT rescue `Exception` to catch it.
- Rescue the socket's errors with `MQTT::Exception`, because the gem doesn't wrap them, e.g. `rescue MQTT::Exception, Errno::ECONNREFUSED, Errno::EPIPE, SocketError => e`.
