---
title: MQTT
parent: Gems
grand_parent: Testing
nav_order: 6
---

# MQTT

How I test code that uses the mqtt gem.

For the code itself, see [MQTT](../../../guide/gems/mqtt/).

The mqtt gem has no stubs of its own, and WebMock can't see its traffic. Specs use a fake client instead, as [Other Services: Fake clients](../../other-services/#fake-clients) describes. This page shows that fake for MQTT.

## Fake client

Define `FakeMqttClient` in `spec/support/mqtt.rb`, with the methods the app calls and the same parameters as `MQTT::Client`. Keep the real names, even for parameters the fake ignores, e.g. `send_msg` in `disconnect`.

`MQTT::Client#get` with a block loops over incoming messages until the socket closes. The fake's `get` yields each queued topic and message in order instead, then returns. Without a block, it returns the next `[topic, message]`, as the real client does. It raises only when nothing was queued.

```ruby
# spec/support/mqtt.rb
class FakeMqttClient
  attr_reader :published, :subscribed_topics, :queued_messages, :reconnects

  def initialize
    @published = []
    @subscribed_topics = []
    @queued_messages = []
    @reconnects = 0
  end

  def connect(clientid = nil)
    @reconnects += 1
  end

  def disconnect(send_msg = true)
  end

  def publish(topic, payload = "", retain = false, qos = 0)
    published << { topic:, payload:, retain:, qos: }
  end

  def subscribe(*topics)
    subscribed_topics.concat(topics)
  end

  def get(topic = nil, options = {})
    raise "No MQTT message queued. Add one with stub_mqtt_message" if queued_messages.empty?
    return queued_messages.shift unless block_given?

    yield(*queued_messages.shift) while queued_messages.any?
  end
end
```

Check the fake against `MQTT::Client` in its own spec, as in [Other Services: Checking the fake](../../other-services/#checking-the-fake).

```ruby
# spec/fakes/fake_mqtt_client_spec.rb
RSpec.describe FakeMqttClient do
  (described_class.public_instance_methods(false) - %i[published subscribed_topics queued_messages reconnects]).each do |name|
    it "matches MQTT::Client##{name}" do
      expect(described_class.instance_method(name).parameters)
        .to eq(MQTT::Client.instance_method(name).parameters)
    end
  end

  describe "#get" do
    it "yields the queued messages in order" do
      client = described_class.new
      client.queued_messages << ["posts/1/read", "first"] << ["posts/2/read", "second"]

      expect { |block| client.get(&block) }
        .to yield_successive_args(["posts/1/read", "first"], ["posts/2/read", "second"])
    end

    it "raises when no message is queued" do
      client = described_class.new

      expect { client.get }.to raise_error(/No MQTT message queued/)
    end
  end

  describe "#subscribe" do
    it "records the topic" do
      client = described_class.new

      client.subscribe("posts/+/read")

      expect(client.subscribed_topics).to eq(["posts/+/read"])
    end
  end
end
```

## Helpers and matchers

Return the fake from `MQTT::Client.connect` in `stub_mqtt_connection`. `PostNotifier` then builds its pool as it does in production, and gets the fake from it. The fake's own `connect` only runs when the service reconnects, so its helper and matcher are `stub_mqtt_reconnect_failure` and `have_reconnected_mqtt_client`.

```ruby
# spec/support/mqtt.rb
module MqttHelpers
  extend RSpec::Matchers::DSL

  def fake_mqtt_client
    @fake_mqtt_client ||= FakeMqttClient.new
  end

  def stub_mqtt_connection
    allow(MQTT::Client).to receive(:connect).and_return(fake_mqtt_client)
    fake_mqtt_client
  end

  def stub_mqtt_message(topic, payload)
    stub_mqtt_connection
    fake_mqtt_client.queued_messages << [topic, payload]
    fake_mqtt_client
  end

  def stub_mqtt_connection_failure(error = MQTT::Exception.new("Connection refused"))
    allow(MQTT::Client).to receive(:connect).and_raise(error)
    fake_mqtt_client
  end

  def stub_mqtt_reconnect_failure(error = MQTT::Exception.new("Connection refused"))
    stub_mqtt_connection
    allow(fake_mqtt_client).to receive(:connect).and_raise(error)
    fake_mqtt_client
  end

  def stub_mqtt_publish_failure(error = MQTT::Exception.new("Not connected"))
    stub_mqtt_connection
    allow(fake_mqtt_client).to receive(:publish).and_raise(error)
    fake_mqtt_client
  end

  # MQTT::Client#disconnect returns early unless it's connected,
  # so it only fails when it writes to the socket.
  def stub_mqtt_disconnect_failure(error = Errno::EPIPE.new)
    stub_mqtt_connection
    allow(fake_mqtt_client).to receive(:disconnect).and_raise(error)
    fake_mqtt_client
  end

  matcher :have_published_mqtt_message do |topic, **options|
    match do |client|
      client.published.any? do |message|
        message[:topic] == topic &&
          options.all? { |key, expected| values_match?(expected, sent_value(message, key, expected)) }
      end
    end

    failure_message do |client|
      "expected a message on #{topic} with #{options.inspect}, got:\n" +
        client.published.map { |message| "  #{message.inspect}" }.join("\n")
    end

    def sent_value(message, key, expected)
      return message[key] if key != :payload || expected.is_a?(String)

      JSON.parse(message[key])
    end
  end

  matcher :have_reconnected_mqtt_client do
    match { |client| client.reconnects.positive? }
  end
end

RSpec.configure do |config|
  config.include MqttHelpers

  config.before do
    allow(MQTT::Client).to receive(:connect)
      .and_raise("Use stub_mqtt_connection or stub_mqtt_message")
  end

  config.after { PostNotifier.const_get(:POOLS).clear }
end
```

A spec keeps the fake that the helper returns, and checks it with the matcher.

```ruby
it "tells the mobile app the post was published" do
  post = create(:post, title: "Hello World")
  mqtt_client = stub_mqtt_connection

  described_class.perform_now(post)

  expect(mqtt_client).to have_published_mqtt_message(
    "posts/#{post.id}/published",
    payload: a_hash_including("title" => "Hello World", "message_id" => a_string_matching(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/))
  )
end
```

`RecordPostReadsJob` reads every queued message in one run. Queue the messages for each run just before it.

```ruby
it "adds the reads from each run to the post" do
  post = create(:post)
  stub_mqtt_message("posts/#{post.id}/read", { "device" => "ios", "app_version" => "3.1" }.to_json)
  described_class.perform_now

  stub_mqtt_message("posts/#{post.id}/read", { "device" => "android", "app_version" => "3.1" }.to_json)
  described_class.perform_now

  expect(post.reload.read_count).to eq(2)
end
```

## Errors

The service rescues `MQTT::Exception` by name, and the socket's errors with it. See [MQTT: Errors](../../../guide/gems/mqtt/#errors). Each failure helper raises what the real method raises, so that code runs as it does in production:

- `stub_mqtt_connection_failure` and `stub_mqtt_reconnect_failure` raise `MQTT::Exception` by default. A connection can also fail on the socket, so pass the error the spec tests, e.g. `stub_mqtt_connection_failure(Errno::ECONNREFUSED)` or `stub_mqtt_connection_failure(SocketError)`.
- `stub_mqtt_publish_failure` raises `MQTT::Exception` by default.
- `stub_mqtt_disconnect_failure` raises `Errno::EPIPE` by default. `MQTT::Client#disconnect` returns early unless it's connected, so it only fails when it writes to the socket.

You MUST NOT make `stub_mqtt_disconnect_failure` raise `MQTT::Exception`. It inherits from `Exception`, not `StandardError`, so it skips a `rescue` that the real error would reach. The spec then fails for a reason production can't hit.

In the service's own spec, build the service with `described_class.default`, so its pool runs, and check that it raises its own error.

```ruby
it "raises its own error when the broker refuses the connection" do
  stub_mqtt_connection_failure(Errno::ECONNREFUSED)

  expect { described_class.default.publish_post(post_id: 1, title: "Hello World") }
    .to raise_error(described_class::Error)
end
```

## Connections

Clear `PostNotifier`'s pools after each spec, as in the support file above. Otherwise the next spec gets the last spec's fake, and its connect stubs never run.

Test keepalive timeouts and TLS in one spec for `PostNotifier`'s connection code, against a real broker or the gem's in-process server, `MQTT::FakeServer`. Use the fake in every other spec.
