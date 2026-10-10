---
title: Agent Instructions
nav_order: 5
permalink: /agent-instructions/
---

# Agent Instructions

Instruction files that make coding agents follow the conventions in [the guide](../guide/). Copy them into the root of your Rails app.
{: .fs-5 .fw-300 }

## Install

From a clone of this repo:

```sh
rsync -a --exclude README.md instructions/ /path/to/your-app/
```

Or without cloning:

```sh
cd /path/to/your-app
curl -sL https://github.com/{{ site.repository }}/archive/refs/heads/{{ site.branch }}.tar.gz \
  | tar -xz --strip-components=2 --exclude=README.md \
    "{{ site.repository | split: '/' | last }}-{{ site.branch }}/instructions"
```

The Copilot files are prefixed with `happy_`, so they sit beside your own files in `.github/instructions/` without overwriting them. If your app already has an `AGENTS.md` or `CLAUDE.md`, merge the content in instead of overwriting it.

## What you get

| File | Read by |
| --- | --- |
| [`.github/instructions/happy_rails.instructions.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/.github/instructions/happy_rails.instructions.md) | GitHub Copilot, for every file |
| [`.github/instructions/happy_*.instructions.md`](https://github.com/{{ site.repository }}/tree/{{ site.branch }}/instructions/.github/instructions) | GitHub Copilot, for files matching each `applyTo` glob |
| [`.github/instructions/happy_setup_*.instructions.md`](https://github.com/{{ site.repository }}/tree/{{ site.branch }}/instructions/.github/instructions) | GitHub Copilot, for the setup files each one creates |
| [`AGENTS.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/AGENTS.md) | Codex, Cursor, Jules and other agents that read `AGENTS.md` |
| [`CLAUDE.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/CLAUDE.md) | Claude Code (imports `AGENTS.md`) |

The area files are:

| File | Applies to |
| --- | --- |
| `happy_rails.instructions.md` | `**` |
| `happy_models.instructions.md` | `app/models/**`, `spec/models/**` |
| `happy_validators.instructions.md` | `app/validators/**`, `spec/validators/**` |
| `happy_forms.instructions.md` | `app/forms/**`, `spec/forms/**` |
| `happy_actions.instructions.md` | `app/actions/**`, `spec/actions/**` |
| `happy_services.instructions.md` | `app/services/**`, `app/forms/**`, `app/controllers/**`, `app/jobs/**` |
| `happy_jobs.instructions.md` | `app/jobs/**`, `lib/tasks/**`, `spec/jobs/**` |
| `happy_controllers.instructions.md` | `app/controllers/**`, `config/routes.rb`, `spec/requests/**`, `spec/features/**` |
| `happy_views.instructions.md` | `app/views/**`, `app/helpers/**`, `app/javascript/**` |
| `happy_mailers.instructions.md` | `app/mailers/**`, `app/views/*_mailer/**`, `spec/mailers/**` |

[Code Style](../guide/code-style/) has its own file. It holds my style preferences, not Happy Rails conventions. If your app has its own style, delete it:

| File | Applies to |
| --- | --- |
| `happy_style.instructions.md` | `app/models/**`, `app/forms/**`, `app/actions/**`, `app/services/**`, `app/controllers/**`, `app/jobs/**`, `app/decorators/**`, `spec/**` |

Each [gem](../guide/gems/) has its own file. If your app does not use a gem, delete its file:

| File | Gem | Applies to |
| --- | --- | --- |
| `happy_devise.instructions.md` | Devise | `config/routes.rb`, `app/models/user.rb`, `app/controllers/users/**`, `app/views/devise/**`, `spec/requests/users/**` |
| `happy_draper.instructions.md` | Draper | `app/decorators/**`, `app/controllers/**`, `app/views/**`, `app/helpers/**`, `spec/decorators/**`, `spec/support/**` |
| `happy_honeybadger.instructions.md` | Honeybadger | `app/models/**`, `app/actions/**`, `app/controllers/**`, `app/jobs/**`, `app/services/**` |
| `happy_pundit.instructions.md` | Pundit | `app/policies/**`, `app/controllers/**`, `app/views/**`, `app/forms/**`, `spec/policies/**` |
| `happy_rspec.instructions.md` | RSpec and FactoryBot | `spec/**` |
| `happy_shoulda_matchers.instructions.md` | Shoulda Matchers | `spec/models/**`, `spec/forms/**` |
| `happy_simple_form.instructions.md` | Simple Form | `app/models/**`, `app/views/**`, `app/inputs/**`, `app/helpers/**`, `config/initializers/simple_form.rb`, `spec/requests/**`, `spec/features/**`, `spec/support/**` |
| `happy_view_component.instructions.md` | ViewComponent | `app/components/**`, `spec/components/**`, `spec/support/**` |
| `happy_webmock.instructions.md` | WebMock and VCR | `spec/**` |
| `happy_wisper.instructions.md` | Wisper | `app/actions/**` |

## Setup files

Some areas and gems have steps an agent does once, when it sets up the app, e.g. writing `ApplicationAction` or the files in `spec/support`. These steps are in their own files, with a `happy_setup_` prefix. Each glob only matches the files that the setup creates or changes, so the steps stay out of the way once the app is set up. Delete a gem's setup file along with its main file. You can delete all the `happy_setup_*` files once your app is set up.

| File | Applies to |
| --- | --- |
| `happy_setup_actions.instructions.md` | `app/actions/application_action.rb`, `app/actions/concerns/**` |
| `happy_setup_forms.instructions.md` | `app/forms/application_form.rb` |
| `happy_setup_validators.instructions.md` | `app/validators/unmodified_validator.rb`, `config/environments/development.rb`, `config/environments/test.rb` |
| `happy_setup_jobs.instructions.md` | `spec/support/active_job.rb` |
| `happy_setup_controllers.instructions.md` | `app/controllers/application_controller.rb`, `config/environments/production.rb` |
| `happy_setup_views.instructions.md` | `app/helpers/unknown_values_helper.rb` |
| `happy_setup_devise.instructions.md` | `config/initializers/devise.rb` |
| `happy_setup_draper.instructions.md` | `app/decorators/application_decorator.rb`, `app/decorators/nil_decorator.rb`, `app/decorators/concerns/**` |
| `happy_setup_honeybadger.instructions.md` | `config/honeybadger.yml`, `app/models/concerns/honeybadger_cause_context.rb` |
| `happy_setup_pundit.instructions.md` | `app/controllers/application_controller.rb`, `app/controllers/concerns/pundit_authorization.rb`, `app/forms/application_form.rb`, `app/forms/concerns/pundit_policies.rb`, `spec/support/pundit.rb` |
| `happy_setup_rspec.instructions.md` | `spec/rails_helper.rb`, `spec/support/time_helpers.rb`, `spec/support/capybara.rb`, `spec/support/forms.rb` |
| `happy_setup_shoulda_matchers.instructions.md` | `spec/support/shoulda_matchers.rb` |
| `happy_setup_view_component.instructions.md` | `spec/support/view_component.rb`, `spec/support/capybara.rb` |
