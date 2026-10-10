---
applyTo: "app/controllers/application_controller.rb,config/environments/production.rb"
---

# Controllers setup

- Put the authentication check in `ApplicationController`, e.g. `before_action :authenticate_user!`.
- Only accept credentials over HTTPS, e.g. `config.force_ssl = true` in production.
- Make every controller require an authorisation check by default. Set this up once in `ApplicationController`.
