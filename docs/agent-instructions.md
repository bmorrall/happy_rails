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
| [`.github/skills/happy-rails-setup/`](https://github.com/{{ site.repository }}/tree/{{ site.branch }}/instructions/.github/skills/happy-rails-setup) | GitHub Copilot, and agents that read `AGENTS.md`, when you set up the app |
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

## Setup skill

Some areas and gems have steps an agent does once, when it sets up the app, e.g. writing `ApplicationAction` or the files in `spec/support`. These steps are in the `happy-rails-setup` skill, not the instruction files, so they stay out of the way once the app is set up.

Ask your agent to set up Happy Rails to run it, e.g. "Set up this app for Happy Rails". The skill reads your `Gemfile` and only runs the steps for the gems you use. It copies the guide's base classes and support files into your app, and skips any file that already exists. Run it again after you add one of the gems. You can delete it once your app is set up.

| Reference | Sets up |
| --- | --- |
| `references/rspec.md` | `spec/rails_helper.rb`, `spec/support/time_helpers.rb`, `spec/support/capybara.rb`, `spec/support/forms.rb` |
| `references/actions.md` | `ApplicationAction`, `ValidatedCallable`, `NonTransactionalCallable` |
| `references/forms.md` | `ApplicationForm` |
| `references/validators.md` | `UnmodifiedValidator`, `raise_on_missing_translations` |
| `references/jobs.md` | `spec/support/active_job.rb` |
| `references/controllers.md` | `ApplicationController`, `force_ssl` |
| `references/views.md` | `UnknownValuesHelper` |
| `references/devise.md` | Devise |
| `references/draper.md` | `NilDecorator`, `ApplicationDecorator` |
| `references/honeybadger.md` | `HoneybadgerCauseContext` |
| `references/pundit.md` | `PunditAuthorization`, `PunditPolicies`, `spec/support/pundit.rb` |
| `references/shoulda_matchers.md` | `spec/support/shoulda_matchers.rb` |
| `references/view_component.md` | `spec/support/view_component.rb` |

Claude Code reads skills from `.claude/skills/`, not `.github/skills/`. To use the skill there, link it:

```sh
mkdir -p .claude/skills
ln -s ../../.github/skills/happy-rails-setup .claude/skills/happy-rails-setup
```
