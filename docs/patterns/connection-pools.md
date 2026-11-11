---
title: Connection Pools
parent: Patterns
nav_order: 5
---

# Connection Pools

How to share connections to another service between threads, when a [service object](../../guide/services/) is built many times.

Opening a connection to another service is slow, so reuse connections from a pool. A pool hands each thread its own connection, and takes it back when the thread is done. One pool works for a service with fixed settings. It gets harder when a service is built from a record, e.g. `NewsletterClient.for(integration)`, because each record can have its own host.

The patterns below use the [connection_pool](https://github.com/mperham/connection_pool) gem. The patterns with more than one pool also use `Concurrent::Map` from concurrent-ruby, which ships with Rails.

## Single pool

When every connection setting comes from `config.x`, the service needs only one pool. Keep it in a private constant on the service, e.g. `POOL`. Ruby loads the class once, so the pool is built once, and you don't need a `Concurrent::Map` or a mutex. Building it is cheap, because `ConnectionPool` opens each connection the first time a thread borrows it. Read the connection settings in the pool's block.

Take the pool as a required first argument to `initialize`, and build the service with `NewsletterClient.default`. You don't need a file in `config/initializers`.

```ruby
class NewsletterClient
  POOL = ConnectionPool.new(size: Rails.application.config.x.newsletter_client.pool_size!) do
    Faraday.new(url: Rails.application.config.x.newsletter_client.base_url!) do |faraday|
      faraday.adapter :net_http_persistent
    end
  end
  private_constant :POOL

  def self.default
    new(POOL, api_key: Rails.application.config.x.newsletter_client.api_key!)
  end

  def initialize(pool, api_key:, api_path: Rails.application.config.x.newsletter_client.api_path!)
    # ...
  end
end
```

A builder that takes only request settings from a record, e.g. the `api_key`, can still use the single pool. When a connection setting comes from a record, e.g. the `base_url` in `NewsletterClient.for(integration)`, switch to [Pool by host](#pool-by-host).

## Pool by host

Keep the credentials out of the connection. A connection only needs the host, e.g. the `base_url`. Send the per-record settings, e.g. the API key, with each request. Then every record that uses the same host shares one pool, and building the service stays cheap: it only keeps the settings, and borrows a connection when it makes a request.

Keep the pools in a `Concurrent::Map`, keyed by host, and create each one the first time it's needed with `compute_if_absent`. The map creates each pool once, even when threads race to create it, so you don't need a mutex. Make the map a private constant, so only `pool_for` can add or read pools.

Take the pool as the first argument to `initialize`, and make it required. Then each method borrows from `pool`. Build the service with a class method that finds the pool, e.g. `NewsletterClient.default` for the app-wide settings in `config.x`, or `NewsletterClient.for(integration)` for settings saved on a record. The connection settings, e.g. the `base_url`, go only to `pool_for`, and `initialize` takes the settings sent with each request, e.g. the `api_key`. Only the builders call `pool_for`, so keep it private, with the code that builds a pool.

You MUST NOT pass a pool to `new` from outside the service, because a pool for the wrong host would send requests there. Only specs and the service's own class methods pass one, e.g. `described_class.new(test_pool, api_key: "test-key")` in a spec.

```ruby
class NewsletterClient
  POOLS = Concurrent::Map.new
  private_constant :POOLS

  class << self
    def default
      new(
        pool_for(base_url: Rails.application.config.x.newsletter_client.base_url!),
        api_key: Rails.application.config.x.newsletter_client.api_key!
      )
    end

    def for(integration)
      new(
        pool_for(base_url: integration.base_url),
        api_key: integration.api_key
      )
    end

    private

    def pool_for(base_url:)
      POOLS.compute_if_absent({ base_url: }) do
        build_pool(base_url:)
      end
    end

    def build_pool(base_url:)
      ConnectionPool.new(size: Rails.application.config.x.newsletter_client.pool_size!) do
        Faraday.new(url: base_url) { |faraday| faraday.adapter :net_http_persistent }
      end
    end
  end

  def initialize(pool, api_key:, api_path: Rails.application.config.x.newsletter_client.api_path!)
    @pool = pool
    @api_key = api_key
    @api_path = api_path
  end

  def create_newsletter(title:, body:)
    pool.with do |connection|
      connection.post(
        "#{api_path}/newsletters",
        newsletter_body(title:, body:),
        "Authorization" => "Bearer #{api_key}"
      )
    end
  end
end
```

connection_pool 2.4 and later reload their pools after a fork, so the pools are safe with Puma in cluster mode. In development, reloading `NewsletterClient` replaces the constant, and the next request builds new pools.

## What goes in the connection

Put only the settings the connection needs in the pool's block, e.g. the host, timeouts, SSL options or a proxy. Send everything else with each request, e.g. the API key, the `api_path` and other headers. Do this even with a single pool and fixed settings. A setting built into a pooled connection is read once, when the pool is created. A spec that builds the service with its own API key would still send the key from the pooled connection.

With a [single pool](#single-pool), read the connection settings from `config.x` in the pool's block. With more than one pool, pass the connection settings to `pool_for` as keywords, with `config.x` defaults for the app-wide ones, e.g. `timeout_seconds:`. `initialize` never takes them, so a service and its pool can't disagree about them. Key the map on every keyword, so different settings never share a pool.

```ruby
class NewsletterClient
  # ...

  class << self
    # ...

    private

    def pool_for(
      base_url:,
      timeout_seconds: Rails.application.config.x.newsletter_client.timeout_seconds!
    )
      POOLS.compute_if_absent({ base_url:, timeout_seconds: }) do
        build_pool(base_url:, timeout_seconds:)
      end
    end

    def build_pool(base_url:, timeout_seconds:)
      ConnectionPool.new(size: Rails.application.config.x.newsletter_client.pool_size!) do
        Faraday.new(url: base_url, request: { timeout: timeout_seconds }) do |faraday|
          faraday.adapter :net_http_persistent
        end
      end
    end
  end

  def initialize(pool, api_key:, api_path: Rails.application.config.x.newsletter_client.api_path!)
    # ...
  end
end
```

The pool size is the exception. It's set for the whole process, so read it from `config.x` in `build_pool`, and leave it out of the key.

When a setting the block reads comes from a record and isn't shared, e.g. a client certificate for each integration, the key is effectively one pool per record. See [Pool per record](#pool-per-record).

## Pool per record

Use a pool per record only when the connection itself depends on the record, e.g. a client certificate for each integration. Pass that setting to `pool_for` as a keyword, and key the map on it, as in [What goes in the connection](#what-goes-in-the-connection). Each record then gets its own pool. A record whose setting changes gets a new pool too, because the key changes with it.

```ruby
class << self
  # ...

  private

  def pool_for(base_url:, client_certificate:)
    POOLS.compute_if_absent({ base_url:, client_certificate: }) do
      build_pool(base_url:, client_certificate:)
    end
  end

  def build_pool(base_url:, client_certificate:)
    ConnectionPool.new(size: Rails.application.config.x.newsletter_client.pool_size!) do
      Faraday.new(url: base_url, ssl: { client_cert: client_certificate }) do |faraday|
        faraday.adapter :net_http_persistent
      end
    end
  end
end
```

The old pool stays in the map, with its connections open. Remove it when you add the new one, and shut it down with `shutdown { |connection| connection.close }`. The block runs for each connection, now or when it is checked back in. This bookkeeping is the cost of this pattern, so prefer [Pool by host](#pool-by-host) when the service allows it.

## The library's own pool

Some client gems pool their own connections, e.g. WaterDrop for Kafka, or an HTTP client with a persistent adapter. Use the library's pool on its own, not inside another one. Set it up in an initializer, as the library's docs describe, because the library manages the connections.

## Pool size

Size a pool for the threads that use it. Set the size in `config.x`, e.g. from `RAILS_MAX_THREADS`, which Puma uses for the web process. A job worker might run a different number of threads, so set the size for each kind of process.

```ruby
# config/application.rb
config.x.newsletter_client.pool_size = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
```
