# Controllers setup

Rules: `.github/instructions/happy_controllers.instructions.md`

- Put the authentication check in `ApplicationController`, e.g. `before_action :authenticate_user!`.
- Only accept credentials over HTTPS, e.g. `config.force_ssl = true` in `config/environments/production.rb`.
- Make every controller require an authorisation check by default. Set this up once in `ApplicationController`. With Pundit, `references/pundit.md` does this.
