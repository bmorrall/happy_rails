---
applyTo: "spec/**/*.rb"
---

# MQTT specs

- Define `FakeMqttClient` in `spec/support/mqtt.rb` with the parameters of `MQTT::Client`, e.g. `publish(topic, payload = "", retain = false, qos = 0)`, `get(topic = nil, options = {})` and `disconnect(send_msg = true)`.
- In `FakeMqttClient#get` with a block, yield each queued topic and message in order, then return, because `MQTT::Client#get` with a block loops until the socket closes. Without a block, return the next `[topic, message]`.
- Return the fake from `MQTT::Client.connect` in `stub_mqtt_connection`. Stub the fake's own `connect` only for a reconnect, e.g. `stub_mqtt_reconnect_failure`, and check it with `have_reconnected_mqtt_client`.
- Default the `connect` and `publish` failure helpers to `MQTT::Exception`, e.g. `def stub_mqtt_connection_failure(error = MQTT::Exception.new("Connection refused"))`, and pass a socket error when the spec tests one, e.g. `stub_mqtt_connection_failure(Errno::ECONNREFUSED)`.
- Default `stub_mqtt_disconnect_failure` to `Errno::EPIPE`, with a comment that `MQTT::Client#disconnect` returns early unless it's connected, so it only fails on the socket write. You MUST NOT make it raise `MQTT::Exception`, which inherits from `Exception` and skips a `rescue` the real error reaches.
- In `PostNotifier`'s spec, build it with `described_class.default` and check that an MQTT or socket failure raises its own error, e.g. `stub_mqtt_connection_failure(Errno::ECONNREFUSED)` then `expect { described_class.default.publish_post(post_id: 1, title: "Hello World") }.to raise_error(described_class::Error)`.
