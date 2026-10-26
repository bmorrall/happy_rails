---
title: Fake Clients
parent: Testing
nav_order: 12
---

# Fake Clients

Fake clients for services that neither WebMock nor an SDK can stub.
{: .fs-5 .fw-300 }

## When to use a fake

Some client gems talk over a socket, not HTTP, e.g. MQTT, AMQP, WebSocket or raw TCP clients. WebMock can't see their traffic, and `WebMock.disable_net_connect!` doesn't block it. When the gem has no stubs of its own, write a fake client in `spec/support`, with helpers and matchers like the ones for WebMock. Specs then read the same whatever the transport: they call `stub_` helpers and check calls with `have_` matchers. See [WebMock and VCR](../gems/webmock/).

Use a fake client only when neither WebMock nor the SDK's own stubs can reach the client. In request, feature, job and service specs, you MUST NOT stub the gem's client class or the service around it, e.g. `instance_double(MQTT::Client)` or `allow(PostNotifier).to receive(:default)`. Inline stubs get copied into every spec that needs them, can only send one message, and skip the service's own code, e.g. its connection pool.

Put everything for the gem in one support file named after it, e.g. `spec/support/mqtt.rb`. Block real connections there for every spec: make the gem's connect method raise in a `before` hook, with a message that names the helpers to use. This does for the socket what `WebMock.disable_net_connect!` does for HTTP.

## The fake

Define one fake, named `Fake` then the client's class, e.g. `FakeMqttClient`. Give it only the methods the app calls, with the same parameters as the real client. Keep the real names even for parameters the fake ignores, e.g. `def disconnect(send_msg = true)`. It records each outbound call, e.g. each message it publishes and each topic it subscribes to.

A blocking read needs a defined end, or the spec waits forever. `MQTT::Client#get` with a block loops over incoming messages until the socket closes. So with a block, the fake yields every queued message in order, then returns. Without a block, it returns the next message. It raises only when nothing was queued, so a spec that forgot to queue a message fails with a clear error.

A fake that raises whenever the queue runs dry ends every job spec in an error, because the job keeps reading. A read stubbed with `and_yield` can only deliver one message.

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

### Checking the fake

A fake can drift from the gem, e.g. when a new version renames a parameter. Give the fake its own spec, which checks that each of its public methods has the same parameters on the real client, as `instance_double` does in a single spec. Loop over `described_class.public_instance_methods(false)`, minus the readers for its recorded calls and its queue, with one example per method. Keep the spec outside `spec/support`, because `rails_helper.rb` loads every file there.

`parameters` compares only the kind and the name of each parameter, not its default. That's why the fake keeps the real names, even for the parameters it ignores.

Add examples for the fake's own behaviour too: messages come back in order, the subscribed topic is recorded, and reading with nothing queued raises.

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

## Helpers

Return the fake from the gem's connect method, not from the service. The service's own code, e.g. its pool and error handling, then runs in the spec too. The class's `connect` returns the fake, so the fake's own `connect` only runs when the service reconnects.

Put the helpers in a module in the same file, with one `stub_` method for each inbound message or failure the specs need. Name each one after the gem and the message, e.g. `stub_mqtt_message`, `stub_mqtt_connection_failure` and `stub_mqtt_publish_failure`. Name it after the place it stubs, too. `stub_mqtt_connection_failure` stubs `MQTT::Client.connect`, and `stub_mqtt_reconnect_failure` stubs the fake's own `connect`.

End every helper by returning the fake. `allow(fake).to receive(:publish).and_raise(error)` returns the stub, not the fake, so a helper that ends on that line hands specs the wrong object. A spec keeps the fake in a local variable, as it does a WebMock stub, e.g. `mqtt_client = stub_mqtt_publish_failure`.

The helpers call `allow` on the fake. You MUST NOT call it in a spec. When a spec needs the fake to do something new, add a helper.

### Failures

A failure helper raises the error the real method raises, so the service's error handling runs as it does in production. Read it from the gem's source. It's usually the gem's own error, e.g. `MQTT::Exception` from `publish`. Sometimes it's the socket's. `MQTT::Client#disconnect` returns early unless it's connected, so it only fails when it writes to the socket, e.g. with `Errno::EPIPE`. When the default isn't the gem's own error, say why in a comment above the helper.

The wrong error can make a spec fail for a reason production can't hit. `MQTT::Exception` inherits from `Exception`, not `StandardError`, so a bare `rescue => e` doesn't catch it. A spec that raises it from `disconnect` tests a failure that can't happen.

Give each failure helper an `error` argument, with the realistic error as its default. Connection code has to handle several errors from the same call, e.g. `Errno::ECONNREFUSED`, `SocketError` and `ConnectionPool::TimeoutError` from `MQTT::Client.connect`. A spec then passes the one it tests, e.g. `stub_mqtt_connection_failure(Errno::ECONNREFUSED)`.

### Inbound messages

Each call to `stub_mqtt_message` queues one more message, so a spec can send several in order. A run reads every message in the queue, so queue the messages for each run just before it, e.g. call `stub_mqtt_message` again before the second `RecordPostReadsJob.perform_now`.

Build each message as a Ruby hash with `to_json`, e.g. `stub_mqtt_message("posts/#{post.id}/read", { "device" => "ios" }.to_json)`. You MUST NOT hand-escape JSON in a string, e.g. `"{\"device\":\"ios\"}"`. It's hard to read, and easy to get wrong. When you convert a string to a hash, check that both parse to the same JSON. A string value such as `"3.1"` has to stay a string.

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

## Matchers

Add a `have_` matcher for each outbound call, named after the verb, the gem and the message, e.g. `have_published_mqtt_message` and `have_reconnected_mqtt_client`. It takes the same arguments as the call, with keywords for the parts the spec checks, and matches them like `have_requested`. RSpec's matcher DSL takes keyword arguments, e.g. `matcher :have_published_mqtt_message do |topic, **options|`.

Parse the payload as JSON inside the matcher, unless the spec passes a string. The service's own spec then checks the exact string it sends, e.g. `payload: { title: "Hello World", id: post.id }.to_json`. Other specs check the parts they're about with `a_hash_including`, not with `JSON.parse` of their own.

Write a `failure_message` that lists every message the fake recorded. When the payload is wrong, the failure then shows what was sent.

For a value the app generates, e.g. a UUID message ID, match its format in request, job and feature specs with `a_string_matching`. Check that two fields hold the same value only in the service's own spec, where the spec passes the value in.

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

## Connections

Give each spec a new fake. Clear the service's cached connections after each spec too, or the next spec gets the last spec's client, and the connect stubs never run.

When the service keeps its connections in a [pool](../../patterns/connection-pools/), the pool can be the code that turns the gem's errors into the service's own, e.g. a `PostNotifier` pool that wraps `MQTT::Exception` in `PostNotifier::ConnectionError`. In service specs, build the service with its own builder, e.g. `described_class.default`, not with a test pool. The pool's error handling is then under test. See [Testing: Services](../services/#settings-from-a-record).

Test reconnecting and error handling with the fake and its failure helpers, e.g. `stub_mqtt_reconnect_failure(Errno::ECONNREFUSED)`. A real broker can't raise a chosen error on demand.

The fake can't test what depends on timing or the wire, e.g. keepalive timeouts and TLS. Test that in one spec for the service's connection code, against a real broker or the gem's in-process server, e.g. `MQTT::FakeServer`. Use the fake client in every other spec. You MUST NOT test what the app does over a real socket.
