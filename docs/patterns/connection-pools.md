---
title: Connection Pools
parent: Patterns
nav_order: 5
---

# Connection Pools

How to share connections to another service between threads, when a [service object](../../guide/services/) is built many times.

Opening a connection to another service is slow, so reuse connections from a pool. A pool hands each thread its own connection, and takes it back when the thread is done. One pool in an initializer works for a single service with fixed settings. It gets harder when a service is built from a record, e.g. `NewsletterClient.for(integration)`, because each record has its own settings.

The patterns below use the [connection_pool](https://github.com/mperham/connection_pool) gem, and `Concurrent::Map` from concurrent-ruby, which ships with Rails.

## Pool by host

Keep the credentials out of the connection. A connection only needs the host, e.g. the `base_url`. Send the per-record settings, e.g. the API key, with each request. Then every record that uses the same host shares one pool, and building the service stays cheap: it only keeps the settings, and borrows a connection when it makes a request.

Keep the pools in a `Concurrent::Map`, keyed by host, and create each one the first time it's needed with `compute_if_absent`. The map creates each pool once, even when threads race to create it, so you don't need a mutex. Make the map a private constant, so only `pool_for` can add or read pools, and keep the code that builds a pool private.

Take the pool as a keyword to `initialize`, with the pool for the service's host as its default. Then each method borrows from `pool`, and a spec can pass its own pool, as with any other setting. Only specs pass it, because a pool for the wrong host would send requests there.

```ruby
class NewsletterClient
  POOLS = Concurrent::Map.new
  private_constant :POOLS

  class << self
    def pool_for(base_url:)
      POOLS.compute_if_absent({ base_url: }) do
        build_pool(base_url:)
      end
    end

    private

    def build_pool(base_url:)
      ConnectionPool.new(size: Rails.application.config.x.newsletter_client.pool_size!) do
        Faraday.new(url: base_url) { |faraday| faraday.adapter :net_http_persistent }
      end
    end
  end

  def initialize(
    api_key:,
    base_url:,
    pool: self.class.pool_for(base_url:)
  )
    # ...
  end

  def create_newsletter(post)
    pool.with do |connection|
      connection.post(
        "#{api_path}/newsletters",
        payload_for(post),
        "Authorization" => "Bearer #{api_key}"
      )
    end
  end
end
```

`pool_for` stays public, because the `pool:` default runs on the instance and calls it through `self.class`. Ruby doesn't allow that call to a private method.

This works for a single service too. With one host, the map holds one pool, and you don't need an initializer.

connection_pool 2.4 and later reload their pools after a fork, so the pools are safe with Puma in cluster mode. In development, reloading `NewsletterClient` replaces the map, and the next request builds new pools.

## What goes in the connection

Put only the settings the connection needs in the pool's block, e.g. the host, timeouts, SSL options or a proxy. Send everything else with each request, e.g. the credentials, the `api_path` and other headers. Do this even with a single pool and fixed settings. A setting built into a pooled connection is read once, when the pool is created. A spec that builds the service with its own API key would still send the key from the pooled connection.

Pass the connection settings to `pool_for` as keywords, from the service's own settings. Then they come from the service's `initialize`, with its `config.x` defaults, and a spec can pass its own. Key the map on every keyword, so services with different settings never share a pool.

```ruby
class NewsletterClient
  # ...

  class << self
    def pool_for(base_url:, timeout_seconds:)
      POOLS.compute_if_absent({ base_url:, timeout_seconds: }) do
        build_pool(base_url:, timeout_seconds:)
      end
    end

    private

    def build_pool(base_url:, timeout_seconds:)
      ConnectionPool.new(size: Rails.application.config.x.newsletter_client.pool_size!) do
        Faraday.new(url: base_url, request: { timeout: timeout_seconds }) do |faraday|
          faraday.adapter :net_http_persistent
        end
      end
    end
  end

  def initialize(
    api_key:,
    base_url:,
    api_path: Rails.application.config.x.newsletter_client.api_path!,
    timeout_seconds: Rails.application.config.x.newsletter_client.timeout_seconds!,
    pool: self.class.pool_for(base_url:, timeout_seconds:)
  )
    # ...
  end
end
```

A keyword's default can use the keywords before it, so the `pool:` default gets the `base_url:` and `timeout_seconds:` the service was built with.

The pool size is the exception. It's set for the whole process, so read it from `config.x` in `build_pool`, and leave it out of the key.

When a setting the block reads comes from a record and isn't shared, e.g. a client certificate for each integration, the key is effectively one pool per record. See [Pool per record](#pool-per-record).

## Pool per record

Use a pool per record only when the connection itself depends on the record, e.g. a client certificate for each integration. Pass that setting to `pool_for` as a keyword, and key the map on it, as in [What goes in the connection](#what-goes-in-the-connection). Each record then gets its own pool. A record whose setting changes gets a new pool too, because the key changes with it.

```ruby
class << self
  def pool_for(base_url:, client_certificate:)
    POOLS.compute_if_absent({ base_url:, client_certificate: }) do
      build_pool(base_url:, client_certificate:)
    end
  end

  private

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

Some client gems pool their own connections, e.g. WaterDrop for Kafka, or an HTTP client with a persistent adapter. Use the library's pool, and don't wrap it in another one. Set it up in an initializer, as the library's docs describe, because the library manages the connections.

## Pool size

Size a pool for the threads that use it. Set the size in `config.x`, e.g. from `RAILS_MAX_THREADS`, which Puma uses for the web process. A job worker may run a different number of threads, so set the size for each kind of process.

```ruby
# config/application.rb
config.x.newsletter_client.pool_size = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
```
