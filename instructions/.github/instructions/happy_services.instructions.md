---
applyTo: "app/services/**/*.rb,app/forms/**/*.rb,app/controllers/**/*.rb,app/jobs/**/*.rb"
---

# Services

- Put service objects in `app/services/`, e.g. `NewsletterClient` in `app/services/newsletter_client.rb`.
- Never give a service object a `call` method. Name each public method after what it does, e.g. `NewsletterClient#create_newsletter` and `NewsletterClient#deliver`.
- Call a service from an action, never from a form or controller, e.g. `NewsletterClient.new.create_newsletter(post)` in `Posts::SendNewsletter#call`. Forms, controllers and jobs call the action. A form or controller may call a service directly only to read a value when nothing changes, e.g. `NewsletterClient.new.fetch_stats(post.newsletter_id)` in a controller. A job may call a service directly only when it is the only place that does the task, e.g. `NewsletterClient.new.deliver(post)` in `NotifySubscribersJob`. Move the call into an action when a second caller needs it.
- Read a service's settings from a `Rails.application.config.x` namespace named after the service, e.g. `config.x.newsletter_client.api_key`. Set the values in one place, e.g. `config/application.rb`, from credentials or `ENV`. Never read `Rails.application.credentials` or `ENV` in a service, and never put a setting straight on `config.x`, e.g. `config.x.newsletter_client_api_key`.
- Take each setting as a keyword argument to `initialize`, with the setting as its default, e.g. `def initialize(api_key: Rails.application.config.x.newsletter_client.api_key!)`. Read required settings with a bang, e.g. `api_key!`, so a missing or blank value raises a `KeyError`. Never pass the settings from app code, e.g. `NewsletterClient.new`, not `NewsletterClient.new(api_key: ...)`. Only specs pass them, e.g. `described_class.new(api_key: "test-key")`.
- TODO: Which kinds of service objects to write.
- TODO: How services raise errors.
- TODO: How to test services.
