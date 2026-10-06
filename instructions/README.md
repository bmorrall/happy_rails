# Happy Rails agent instructions

Copy everything in this directory except this README, including the hidden `.github` directory, into the root of your Rails app:

```sh
rsync -a --exclude README.md instructions/ /path/to/your-app/
```

| File | Read by |
| --- | --- |
| `.github/instructions/happy_rails.instructions.md` | GitHub Copilot (all files) |
| `.github/instructions/happy_*.instructions.md` | GitHub Copilot (files matching `applyTo`) |
| `AGENTS.md` | Codex, Cursor, Jules and other agents that read AGENTS.md |
| `CLAUDE.md` | Claude Code (imports AGENTS.md) |

The Copilot files are prefixed with `happy_`, so they sit beside your own files in `.github/instructions/` without overwriting them. If your app already has an `AGENTS.md` or `CLAUDE.md`, merge the content in instead of overwriting it.

`happy_style` holds my style preferences, not Happy Rails conventions. If your app has its own style, delete it.

The gem files (`happy_devise`, `happy_draper`, `happy_honeybadger`, `happy_pundit`, `happy_rspec`, `happy_shoulda_matchers`, `happy_simple_form`, `happy_view_component` and `happy_webmock`) only matter if your app uses that gem. Delete the ones you do not need.
