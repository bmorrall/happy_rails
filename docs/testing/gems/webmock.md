---
title: WebMock and VCR
parent: Gems
grand_parent: Testing
nav_order: 12
---

# WebMock and VCR

Stubbed HTTP requests in specs with [WebMock](https://github.com/bblimke/webmock) and [VCR](https://github.com/vcr/vcr).

## Stubbing requests

WebMock blocks every real HTTP request in specs. In request, feature, job and service specs, stub each request the code makes to another service with `stub_request`, and check that the code made it. Stub the request, not the service class that makes it, so the spec runs the service's code too. Action specs are unit specs, so they stub the service instead. See [Testing: Actions](../../actions/).

To test the other service failing, stub the request to fail. Use `.to_return(status: 500)` when the service returns an error, and `.to_timeout` when it takes too long to reply.

```ruby
stub_request(:post, "https://newsletter.example.com/posts").to_timeout
```

You MUST NOT call `stub_request` in the specs themselves. Wrap it in a helper for the service, as below. When a spec needs a stub or a check that has no helper yet, add the helper first.

### Helpers and matchers

A stub repeats the service's URL, and often its response body, in every spec that uses it. Put the stubs for each service in a helper module in `spec/support`, with one method for each response the specs need: the reply the service sends when it works, an error and a timeout. Start each method's name with `stub_`, then the service and the request, e.g. `stub_newsletter_create`. Return the WebMock stub from each method.

Then a spec says what the service does, not how its API works. When the API changes, you fix one file, not every spec.

```ruby
# spec/support/newsletter_service.rb
module NewsletterServiceHelpers
  def stub_newsletter_create(id: "newsletter-1")
    stub_request(:post, "https://newsletter.example.com/posts")
      .to_return(status: 201, body: { id: }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_newsletter_create_failure(status: 500)
    stub_request(:post, "https://newsletter.example.com/posts")
      .to_return(status:)
  end

  def stub_newsletter_create_timeout
    stub_request(:post, "https://newsletter.example.com/posts")
      .to_timeout
  end
end

RSpec.configure do |config|
  config.include NewsletterServiceHelpers
end
```

When a spec checks a value from the response, pass it to the helper, e.g. `stub_newsletter_create(id: "newsletter-1")`. You SHOULD give each of the helper's arguments a default, so specs that don't check them can leave them out. See [RSpec: Values you check](../rspec/#values-you-check).

Call the helper inside the example. Avoid calling it in a `let` or a `before` block. Keep the stub it returns in a local variable, and check it with `have_been_requested`. The example then shows the stub and the check together, and the variable says which request you expect.

```ruby
it "sends the post to the newsletter service" do
  post = create(:post)
  newsletter_request = stub_newsletter_create

  described_class.perform_now(post)

  expect(newsletter_request).to have_been_requested
end
```

When a spec also checks what the request sent, e.g. the post's title, add a matcher to the same module. Write it as a method that returns WebMock's own `have_requested` matcher, and use it on `WebMock`. Start its name with `have_requested_`, then the same service and request as the stub, e.g. `have_requested_newsletter_create`. Pass its keywords to WebMock's `with`, e.g. `body:` and `headers:`. Call `with` only when there are keywords. It raises an error when called with no options, so `expect(WebMock).to have_requested_newsletter_create` would break. When the matcher fails, WebMock lists the requests that were made.

```ruby
# spec/support/newsletter_service.rb
module NewsletterServiceHelpers
  # ...

  def have_requested_newsletter_create(**options)
    matcher = have_requested(:post, "https://newsletter.example.com/posts")
    options.any? ? matcher.with(**options) : matcher
  end
end
```

Check only the parts of the request the spec is about, with `hash_including`. The service's own spec checks the whole request. See [Testing: Services](../../services/#full-messages).

```ruby
it "sends the post's title to the newsletter service" do
  post = create(:post, title: "Hello World")
  stub_newsletter_create

  described_class.perform_now(post)

  expect(WebMock).to have_requested_newsletter_create(body: hash_including(title: "Hello World"))
end
```

### SDK stubs

Some services come with an SDK that has its own stubs, e.g. `stub_responses` in the AWS SDK. Use them instead of WebMock. They replace only the SDK's HTTP layer, so your service's code still runs, and you don't write signed requests or response bodies by hand. Outside action specs, you MUST NOT stub the service class itself.

Turn the stubs on for every spec, and set the responses for a spec in `Aws.config`. Remove them after each spec, so they don't leak into the next one.

```ruby
# spec/support/aws.rb
Aws.config.update(stub_responses: true)

RSpec.configure do |config|
  config.after { Aws.config.delete(:s3) }
end
```

To check the request, stub the response with a block that keeps its params.

```ruby
it "saves a copy of the post to S3" do
  post = create(:post, published_at: Time.zone.now)
  uploads = []
  Aws.config[:s3] = {
    stub_responses: { put_object: ->(context) { uploads << context.params; {} } }
  }

  described_class.perform_now(post)

  expect(uploads).to contain_exactly(hash_including(key: "posts/#{post.id}.json"))
end
```

To test the service failing, stub the response with the error's code, e.g. `Aws.config[:s3] = { stub_responses: { put_object: "ServiceUnavailable" } }`. The client then raises `Aws::S3::Errors::ServiceUnavailable`.

Put SDK stubs behind helpers too, as in [Helpers and matchers](#helpers-and-matchers), e.g. `stub_post_backup_upload`.

When neither WebMock nor the SDK can reach the client, use a fake client, as in [Clients without stubs](#clients-without-stubs).

### Clients without stubs

Some client gems talk over a socket, not HTTP, e.g. MQTT, AMQP, WebSocket or raw TCP clients. WebMock can't see their traffic, and `WebMock.disable_net_connect!` doesn't block it. When the gem has no stubs of its own, write a fake client in `spec/support`, with helpers and matchers like the ones for WebMock. Specs then read the same whatever the transport: they call `stub_` helpers and check calls with `have_` matchers. Use a fake client only when neither WebMock nor the SDK's own stubs can reach the client.

In request, feature, job and service specs, you MUST NOT stub the gem's client class or the service around it, e.g. `instance_double(MQTT::Client)` or `allow(PostNotifier).to receive(:default)`. Inline stubs get copied into every spec that needs them, can only send one message, and skip the service's own code, e.g. its connection pool.

Put everything for the gem in one support file named after it, e.g. `spec/support/mqtt.rb`. Block real connections there for every spec: make the gem's connect method raise in a `before` hook, with a message that names the helpers to use. This does for the socket what `WebMock.disable_net_connect!` does for HTTP.

Define one fake, named `Fake` then the client's class, e.g. `FakeMqttClient`. Give it only the methods the app calls, with the same parameters as the real client. It records each outbound call, and returns the queued inbound messages in order. It raises when the code reads a message that wasn't queued, so a spec never waits on a socket.

Return the fake from the gem's connect method, not from the service. The service's own code, e.g. its pool and error handling, then runs in the spec too.

Put the helpers in a module in the same file, with one `stub_` method for each inbound message or failure the specs need. Name each one after the gem and the message, e.g. `stub_mqtt_message`, `stub_mqtt_connection_failure` and `stub_mqtt_publish_failure`. A failure helper raises the gem's own error, e.g. `MQTT::Exception`, so the service's error handling runs. Each call to `stub_mqtt_message` queues one more message, so a spec can send several in order.

Add a `have_` matcher for each outbound call, named after the verb, the gem and the message, e.g. `have_published_mqtt_message`. It takes the same arguments as the call, with keywords for the parts the spec checks, and matches them like `have_requested`. Parse a JSON payload inside the matcher, so specs check it with `hash_including`, not with `JSON.parse` of their own.

Give each spec a new fake. Clear the service's cached connections after each spec too, or the next spec gets the last spec's client, and the connect stubs never run.

```ruby
# spec/support/mqtt.rb
class FakeMqttClient
  attr_reader :published, :queue

  def initialize
    @published = []
    @queue = []
  end

  def publish(topic, payload = "", retain = false, qos = 0)
    published << { topic:, payload:, retain:, qos: }
  end

  def get(topic = nil, options = {})
    raise "No MQTT message queued. Add one with stub_mqtt_message" if queue.empty?

    queue.shift
  end
end

module MqttHelpers
  extend RSpec::Matchers::DSL

  def fake_mqtt_client
    @fake_mqtt_client ||= FakeMqttClient.new
  end

  def stub_mqtt_connection
    allow(MQTT::Client).to receive(:connect).and_return(fake_mqtt_client)
  end

  def stub_mqtt_message(topic, payload)
    stub_mqtt_connection
    fake_mqtt_client.queue << [topic, payload]
  end

  def stub_mqtt_connection_failure
    allow(MQTT::Client).to receive(:connect).and_raise(MQTT::Exception)
  end

  def stub_mqtt_publish_failure
    stub_mqtt_connection
    allow(fake_mqtt_client).to receive(:publish).and_raise(MQTT::Exception)
  end

  matcher :have_published_mqtt_message do |topic, payload: anything|
    match do |client|
      client.published.any? do |message|
        message[:topic] == topic && values_match?(payload, JSON.parse(message[:payload]))
      end
    end

    failure_message do |client|
      "expected a message on #{topic}, got #{client.published.inspect}"
    end
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

The helpers call `allow` on the fake. You MUST NOT call it in a spec. When a spec needs the fake to do something new, add a helper.

```ruby
it "tells the mobile app the post was published" do
  post = create(:post, title: "Hello World")
  stub_mqtt_connection

  described_class.perform_now(post)

  expect(fake_mqtt_client).to have_published_mqtt_message(
    "posts/#{post.id}/published",
    payload: hash_including("title" => "Hello World")
  )
end
```

A fake can drift from the gem, e.g. when a new version renames a parameter. Give the fake its own spec, which checks that each of its public methods has the same parameters on the real client, as `instance_double` does in a single spec. Leave out the readers for its recorded calls and its queue. Keep the spec outside `spec/support`, because `rails_helper.rb` loads every file there.

```ruby
# spec/fakes/fake_mqtt_client_spec.rb
RSpec.describe FakeMqttClient do
  (described_class.public_instance_methods(false) - %i[published queue]).each do |name|
    it "matches MQTT::Client##{name}" do
      expect(described_class.instance_method(name).parameters)
        .to eq(MQTT::Client.instance_method(name).parameters)
    end
  end
end
```

The fake can't test the connection itself, e.g. reconnecting, keepalive or TLS. Test that in one spec for the service's connection code, against a real broker or the gem's in-process server, e.g. `MQTT::FakeServer`. Use the fake client in every other spec. You MUST NOT test what the app does over a real socket.

## Recording requests

> **TODO:** Describe how you handle this.
