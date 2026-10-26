---
title: Other Services
parent: Testing
nav_order: 12
---

# Other Services

Stubbing the requests and messages an app sends to other services, whatever the transport.
{: .fs-5 .fw-300 }

## Stubbing other services

In request, feature, job and service specs, stub each request or message the code sends to another service, and check that the code sent it. Stub it at the transport, not the service class that sends it, so the spec runs the service's code too. You MUST NOT stub the service class in those specs, e.g. `allow(NewsletterClient).to receive(:new)` or `allow(PostNotifier).to receive(:default)`. Action specs are unit specs, so they stub the service instead. See [Testing: Actions](../actions/).

How you stub the transport depends on the client:

- For HTTP, use WebMock. See [WebMock and VCR](../gems/webmock/).
- When the service's SDK has its own stubs, use them instead of WebMock, e.g. `stub_responses` in the AWS SDK. See [SDK stubs](#sdk-stubs).
- When neither WebMock nor the SDK can reach the client, e.g. a socket client such as the `mqtt` gem, use a fake client. See [Fake clients](#fake-clients).

Block real connections in every spec, so a spec that forgot a stub fails instead of reaching the service. WebMock does this for HTTP. For an SDK or a fake client, do it in the support file, as below.

## Helpers

A stub repeats the service's address, and often its reply, in every spec that uses it. Put the stubs for each service in a helper module in `spec/support`, included in every spec, with one method for each response the specs need: the reply the service sends when it works, a failure and, when the service can be slow, a timeout. Start each method's name with `stub_`, then the service and the request or message, e.g. `stub_newsletter_create`, `stub_newsletter_create_failure` and `stub_newsletter_create_timeout`.

Then a spec says what the service does, not how its API works. When the API changes, you fix one file, not every spec.

You MUST NOT stub the transport in the specs themselves, e.g. with `stub_request`, `Aws.config` or `allow` on a fake. When a spec needs a stub or a check that has no helper yet, add the helper first.

When a spec checks a value from the reply, pass it to the helper, e.g. `stub_newsletter_create(id: "newsletter-1")`. You SHOULD give each of the helper's arguments a default, so specs that don't check them can leave them out. See [RSpec: Values you check](../gems/rspec/#values-you-check).

Return what the spec checks from every helper, e.g. the WebMock stub, or the fake client. Call the helper inside the example. Avoid calling it in a `let` or a `before` block. Keep what it returns in a local variable, e.g. `newsletter_request = stub_newsletter_create` or `mqtt_client = stub_mqtt_connection`. The example then shows the stub and the check together. See [WebMock and VCR: Helpers](../gems/webmock/#helpers) for HTTP helpers, and [Helpers for a fake](#helpers-for-a-fake) for a socket.

### Failures

A failure helper fails the way the real service does, so the service's error handling runs as it does in production. Give it an argument for the failure, with the most likely failure as its default, e.g. `status: 500` in `stub_newsletter_create_failure`. A spec then passes the one it tests, e.g. `stub_newsletter_create_failure(status: 422)`.

### Bodies and messages

Build each body or message a helper returns, or a spec queues, in Ruby, e.g. as a hash. Then convert it to the service's format, e.g. `body: { id: }.to_json`, or with `to_xml` or `URI.encode_www_form`. The Ruby shows the structure, and the library gets the escaping right.

You SHOULD NOT write a body or message as a raw string, e.g. `"{\"id\":\"newsletter-1\"}"`. It's hard to read, and easy to get wrong. When you convert a string to Ruby, check that both give the same body. A string value such as `"3.1"` has to stay a string.

## Matchers

When a spec checks what a request or message sent, e.g. the post's title, add a `have_` matcher to the same module. Name it after the verb, then the same service and request as the stub, e.g. `have_requested_newsletter_create`. It takes keywords for the parts the spec checks, e.g. `body:` or `payload:`. When it fails, it lists what was sent, so a wrong payload shows what the code did send.

Check only the parts the spec is about, with `hash_including`. The service's own spec checks the whole message. See [Testing: Services](../services/#full-messages).

For a value the app generates, e.g. a UUID message ID, match its format in request, job and feature specs with `a_string_matching`. Check that two fields hold the same value only in the service's own spec, where the spec passes the value in.

## SDK stubs

Some services come with an SDK that has its own stubs, e.g. `stub_responses` in the AWS SDK. Use them instead of WebMock. They replace only the SDK's HTTP layer, so your service's code still runs, and you don't write signed requests or response bodies by hand.

Turn the stubs on for every spec in a support file named after the SDK, and set the responses for a spec in `Aws.config`. Remove them after each spec, so they don't leak into the next one.

```ruby
# spec/support/aws.rb
Aws.config.update(stub_responses: true)

RSpec.configure do |config|
  config.after { Aws.config.delete(:s3) }
end
```

Put the responses behind helpers, as in [Helpers](#helpers). To check the request, stub the response with a block that keeps its params, and return them from the helper. To test the service failing, stub the response with the error's code, e.g. `"ServiceUnavailable"`. The client then raises `Aws::S3::Errors::ServiceUnavailable`.

```ruby
# spec/support/aws.rb
module AwsHelpers
  def stub_post_backup_upload
    uploads = []
    Aws.config[:s3] = { stub_responses: { put_object: ->(context) { uploads << context.params; {} } } }
    uploads
  end

  def stub_post_backup_upload_failure(code = "ServiceUnavailable")
    Aws.config[:s3] = { stub_responses: { put_object: code } }
  end
end

RSpec.configure do |config|
  config.include AwsHelpers
end
```

```ruby
it "saves a copy of the post to S3" do
  post = create(:post, published_at: Time.zone.now)
  uploads = stub_post_backup_upload

  described_class.perform_now(post)

  expect(uploads).to contain_exactly(hash_including(key: "posts/#{post.id}.json"))
end
```

## Fake clients

Some client gems talk over a socket, not HTTP, e.g. MQTT, AMQP, WebSocket or raw TCP clients. WebMock can't see their traffic, and `WebMock.disable_net_connect!` doesn't block it. When the gem has no stubs of its own, write a fake client in `spec/support`. Specs then read the same whatever the transport: they call `stub_` helpers and check calls with `have_` matchers. Use a fake client only when neither WebMock nor the SDK's own stubs can reach the client. In request, feature, job and service specs, you MUST NOT stub the gem's client class either, e.g. `instance_double(MQTT::Client)`. Inline stubs get copied into every spec that needs them, can only send one message, and skip the service's own code, e.g. its connection pool.

Put everything for the gem in one support file named after it, e.g. `spec/support/mqtt.rb`. Block real connections there for every spec: make the gem's connect method raise in a `before` hook, with a message that names the helpers to use. This does for the socket what `WebMock.disable_net_connect!` does for HTTP.

For a full example, see [Testing: MQTT](../gems/mqtt/).

### The fake

Define one fake, named `Fake` then the client's class, e.g. `FakeMqttClient`. Give it only the methods the app calls, with the same parameters as the real client. Keep the real names even for parameters the fake ignores. It records each outbound call, e.g. each message it publishes and each topic it subscribes to.

A blocking read needs a defined end, or the spec waits forever. With a block, the fake yields every queued message in order, then returns. Without a block, it returns the next message. It raises only when nothing was queued, so a spec that forgot to queue a message fails with a clear error.

A fake that raises whenever the queue runs dry ends every job spec in an error, because the job keeps reading. A read stubbed with `and_yield` can only deliver one message.

### Checking the fake

A fake can drift from the gem, e.g. when a new version renames a parameter. Give the fake its own spec, which checks that each of its public methods has the same parameters on the real client, as `instance_double` does in a single spec. Loop over `described_class.public_instance_methods(false)`, minus the readers for its recorded calls and its queue, with one example per method. Keep the spec outside `spec/support`, because `rails_helper.rb` loads every file there.

`parameters` compares only the kind and the name of each parameter, not its default. That's why the fake keeps the real names, even for the parameters it ignores.

Add examples for the fake's own behaviour too: messages come back in order, the subscribed topic is recorded, and reading with nothing queued raises.

### Helpers for a fake

Return the fake from the gem's connect method, not from the service. The service's own code, e.g. its pool and error handling, then runs in the spec too. The class's connect method returns the fake, so the fake's own `connect` only runs when the service reconnects.

Name each helper after the gem and the message, as in [Helpers](#helpers), e.g. `stub_mqtt_message` and `stub_mqtt_publish_failure`. Name it after the method it stubs, too, e.g. `stub_mqtt_connection_failure` for the class's `connect` and `stub_mqtt_reconnect_failure` for the fake's own.

End every helper by returning the fake. `allow(fake).to receive(:publish).and_raise(error)` returns the stub, not the fake, so a helper that ends on that line hands specs the wrong object.

A failure helper raises the error the real method raises. Read it from the gem's source. It's usually the gem's own error, but sometimes the socket's. When the default isn't the gem's own error, say why in a comment above the helper. The wrong error can make a spec fail for a reason production can't hit, e.g. when it skips a `rescue` that the real error would reach.

Give each failure helper an `error` argument, with the real method's error as its default. Connection code has to handle several errors from the same call, e.g. a refused connection, an unknown host and a pool timeout. A spec then passes the one it tests, e.g. `stub_mqtt_connection_failure(Errno::ECONNREFUSED)`.

Each call to a message helper queues one more message, so a spec can send several in order. A run reads every message in the queue, so queue the messages for each run just before it.

### Matchers for a fake

Add a `have_` matcher for each outbound call, e.g. `have_published_mqtt_message`. It takes the same arguments as the call, with keywords for the parts the spec checks, and matches them like `have_requested`. RSpec's matcher DSL takes keyword arguments, e.g. `matcher :have_published_mqtt_message do |topic, **options|`.

Parse the payload from its format inside the matcher, e.g. JSON, unless the spec passes a string. The service's own spec then checks the exact string it sends, e.g. `payload: { title: "Hello World", id: post.id }.to_json`. Other specs check the parts they're about with `a_hash_including`, not with `JSON.parse` of their own.

WebMock lists the requests that were made when its matcher fails. Do the same for a fake: write a `failure_message` that lists every message the fake recorded.

### Connections for a fake

Give each spec a new fake. Clear the service's cached connections after each spec too, or the next spec gets the last spec's client, and the connect stubs never run.

When the service keeps its connections in a [pool](../../patterns/connection-pools/), the pool can be the code that turns the gem's errors into the service's own. In service specs, build the service with its own builder, e.g. `described_class.default`, not with a test pool. The pool's error handling is then under test. See [Testing: Services](../services/#settings-from-a-record).

Test reconnecting and error handling with the fake and its failure helpers, e.g. `stub_mqtt_reconnect_failure(Errno::ECONNREFUSED)`. A real server can't raise a chosen error on demand.

The fake can't test what depends on timing or the wire, e.g. keepalive timeouts and TLS. Test that in one spec for the service's connection code, against a real server or the gem's in-process server, e.g. `MQTT::FakeServer`. Use the fake client in every other spec. You MUST NOT test what the app does over a real socket.
