---
applyTo: "app/services/**/*.rb,app/forms/**/*.rb,app/controllers/**/*.rb,app/jobs/**/*.rb"
---

# Services

- Put service objects in `app/services/`, e.g. `NewsletterClient` in `app/services/newsletter_client.rb`.
- Never give a service object a `call` method. Name each public method after what it does, e.g. `NewsletterClient#create_newsletter` and `NewsletterClient#deliver`.
- Call a service from an action, never from a form or controller, e.g. `NewsletterClient.new.create_newsletter(post)` in `Posts::SendNewsletter#call`. Forms, controllers and jobs call the action. A job may call a service directly only when it is the only place that does the task, e.g. `NewsletterClient.new.deliver(post)` in `NotifySubscribersJob`. Move the call into an action when a second caller needs it.
- TODO: Which kinds of service objects to write.
- TODO: How services raise errors.
- TODO: How to test services.
