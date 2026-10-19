---
title: Tooling and CI
parent: The Guide
nav_order: 13
---

# Tooling and CI

Linting, security checks, request timeouts and continuous integration.

## Linting

> **TODO:** Describe how you handle this.

### Nested modules

Enable RuboCop's `Style/ClassAndModuleChildren` cop with the `nested` style. It checks that every namespaced class is defined inside a `module` block. See [Directory Layout: Namespaced classes](../directory-layout/#namespaced-classes). Some configs turn the cop off, e.g. Standard, so turn it on in your own config.

```yaml
Style/ClassAndModuleChildren:
  Enabled: true
  EnforcedStyle: nested
```

## Request timeouts

Heroku's router cuts a request off after 30 seconds, and returns an error to the user. The app doesn't know: the request keeps running, and holds a worker until it ends.

Stop the request in the app first, with [rack-timeout](https://github.com/zombocom/rack-timeout). Set its `service_timeout` to 15 seconds, well inside the router's limit. A slow request then raises `Rack::Timeout::RequestTimeoutException`, your error reports show where it was stuck, and the worker is free again.

```ruby
# Gemfile
gem "rack-timeout", require: "rack/timeout/base"
```

```ruby
# config/initializers/rack_timeout.rb
Rails.application.config.middleware.insert_before Rack::Runtime, Rack::Timeout,
  service_timeout: 15
```

A request that calls another service gives up on it before this limit. See [Services: Timeouts](../services/#timeouts).

## Security scanning

> **TODO:** Describe how you handle this.

## bin scripts

> **TODO:** Describe how you handle this.

## Continuous integration

> **TODO:** Describe how you handle this.
