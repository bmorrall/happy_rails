# Rails setup

Rules: `.github/instructions/happy_rails.instructions.md`

- Stop slow requests before the host cuts them off: add `gem "rack-timeout", require: "rack/timeout/base"` to the `Gemfile`, run `bundle install`, and write `config/initializers/rack_timeout.rb`, which inserts `Rack::Timeout` before `Rack::Runtime` with `service_timeout: 15`. Copy `assets/config/initializers/rack_timeout.rb`.
