---
title: Agent Instructions
nav_order: 3
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
| [`AGENTS.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/AGENTS.md) | Codex, Cursor, Jules and other agents that read `AGENTS.md` |
| [`CLAUDE.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/CLAUDE.md) | Claude Code (imports `AGENTS.md`) |

The area files are:

| File | Applies to |
| --- | --- |
| `happy_rails.instructions.md` | `**` |
| `happy_models.instructions.md` | `app/models/**`, `spec/models/**` |
| `happy_forms.instructions.md` | `app/forms/**`, `spec/forms/**` |
| `happy_controllers.instructions.md` | `app/controllers/**`, `config/routes.rb`, `spec/requests/**`, `spec/features/**` |
| `happy_views.instructions.md` | `app/views/**`, `app/helpers/**`, `app/javascript/**` |
| `happy_jobs.instructions.md` | `app/jobs/**`, `spec/jobs/**` |
| `happy_mailers.instructions.md` | `app/mailers/**`, `app/views/*_mailer/**`, `spec/mailers/**` |

Each [gem](../guide/gems/) has its own file. If your app does not use a gem, delete its file:

| File | Gem | Applies to |
| --- | --- | --- |
| `happy_devise.instructions.md` | Devise | `config/initializers/devise.rb`, `config/routes.rb`, `app/models/user.rb`, `app/controllers/users/**`, `app/views/devise/**`, `spec/requests/users/**` |
| `happy_draper.instructions.md` | Draper | `app/decorators/**`, `app/controllers/**`, `app/views/**`, `app/helpers/**`, `spec/decorators/**`, `spec/support/**` |
| `happy_pundit.instructions.md` | Pundit | `app/policies/**`, `app/controllers/**`, `app/views/**`, `app/forms/**`, `spec/policies/**` |
| `happy_rspec.instructions.md` | RSpec and FactoryBot | `spec/**` |
| `happy_shoulda_matchers.instructions.md` | Shoulda Matchers | `spec/models/**`, `spec/forms/**` |
| `happy_simple_form.instructions.md` | Simple Form | `app/models/**`, `app/views/**`, `app/inputs/**`, `app/helpers/**`, `config/initializers/simple_form.rb`, `spec/requests/**`, `spec/features/**`, `spec/support/**` |
| `happy_view_component.instructions.md` | ViewComponent | `app/components/**`, `spec/components/**`, `spec/support/**` |
