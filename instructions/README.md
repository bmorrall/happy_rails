# Happy Rails agent instructions

Copy everything in this directory except this README, including the hidden `.github` directory, into the root of your Rails app:

```sh
rsync -a --exclude README.md instructions/ /path/to/your-app/
```

| File | Read by |
| --- | --- |
| `.github/instructions/happy_rails.instructions.md` | GitHub Copilot (all files) |
| `.github/instructions/happy_*.instructions.md` | GitHub Copilot (files matching `applyTo`) |
| `.github/skills/happy-rails-setup/` | GitHub Copilot, and agents that read `AGENTS.md` (set up the app once) |
| `AGENTS.md` | Codex, Cursor, Jules and other agents that read AGENTS.md |
| `CLAUDE.md` | Claude Code (imports AGENTS.md) |

The Copilot files are prefixed with `happy_`, so they sit beside your own files in `.github/instructions/` without overwriting them. If your app already has an `AGENTS.md` or `CLAUDE.md`, merge the content in instead of overwriting it.

The `happy-rails-setup` skill holds steps an agent does once, e.g. writing `ApplicationAction` or the files in `spec/support`. Ask your agent to set up Happy Rails to run it. It only runs the steps for the gems in your `Gemfile`, and skips steps that are already done. You can delete it once your app is set up.

Claude Code reads skills from `.claude/skills/`, not `.github/skills/`. To use the skill there, link it:

```sh
mkdir -p .claude/skills
ln -s ../../.github/skills/happy-rails-setup .claude/skills/happy-rails-setup
```

`happy_style` and `happy_rspec_style` hold my style preferences, not Happy Rails conventions. If your app has its own style, delete them.

The gem files (`happy_aasm`, `happy_devise`, `happy_draper`, `happy_dry_rb`, `happy_honeybadger`, `happy_pundit`, `happy_simple_form`, `happy_turbo`, `happy_view_component` and `happy_wisper`) only matter if your app uses that gem. Delete the ones you do not need, with their `happy_rspec_` files, e.g. `happy_rspec_pundit`.

The `happy_rspec*` files hold the rules for specs, written for RSpec, e.g. `happy_rspec_actions` for `spec/actions/`. If your app does not use RSpec, delete all of them. `happy_rspec_shoulda_matchers` and `happy_rspec_webmock` only matter if your app uses Shoulda Matchers or WebMock.
