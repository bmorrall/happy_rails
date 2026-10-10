---
name: happy-rails-setup
description: Set up a Rails app for the Happy Rails conventions. Writes the base classes, shared concerns, config settings and spec/support files the conventions rely on, e.g. ApplicationAction, ApplicationForm and UnmodifiedValidator, plus the setup for each supported gem the app uses (Devise, Draper, Honeybadger, Pundit, RSpec, Shoulda Matchers, ViewComponent). Use when starting a new Rails app, when adding Happy Rails to an existing app, after adding one of those gems, or when a class the instructions name, e.g. ApplicationAction or PunditAuthorization, does not exist yet.
---

# Happy Rails setup

These steps set up a Rails app for the Happy Rails conventions: https://bmorrall.github.io/happy_rails/

Do them once. The rules in `.github/instructions/happy_*.instructions.md` assume they are done.

## Steps

1. Read the `Gemfile` to find which gems the app uses.
2. Work through the reference files in the order of the table below. Skip a gem's file when the gem is not in the `Gemfile`. Skip the steps that write `spec/` files when the app does not use RSpec.
3. Where a step names a file in `assets/`, copy it to the same path in the app, e.g. `assets/app/actions/application_action.rb` to `app/actions/application_action.rb`.
4. Before you write a file, check whether it exists. If it does, add only the parts it is missing, and never overwrite it. Skip a step that is already done. Each reference names its instruction file on its `Rules:` line. Read that file before you change an existing file, so the changes still follow it.
5. When you finish, list the files you created, the files you changed and the steps you skipped.

| Reference | When |
| --- | --- |
| `references/rspec.md` | The app uses `rspec-rails` |
| `references/actions.md` | Always |
| `references/forms.md` | Always |
| `references/validators.md` | Always |
| `references/jobs.md` | Always |
| `references/controllers.md` | Always |
| `references/views.md` | Always |
| `references/devise.md` | The app uses `devise` |
| `references/draper.md` | The app uses `draper` |
| `references/honeybadger.md` | The app uses `honeybadger` |
| `references/pundit.md` | The app uses `pundit` |
| `references/shoulda_matchers.md` | The app uses `shoulda-matchers` |
| `references/view_component.md` | The app uses `view_component` |
