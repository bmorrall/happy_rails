# Happy Rails agent instructions

Copy everything in this directory except this README, including the hidden `.github` directory, into the root of your Rails app:

```sh
rsync -a --exclude README.md instructions/ /path/to/your-app/
```

| File | Read by |
| --- | --- |
| `.github/copilot-instructions.md` | GitHub Copilot (all requests) |
| `.github/instructions/*.instructions.md` | GitHub Copilot (files matching `applyTo`) |
| `AGENTS.md` | Codex, Cursor, Jules and other agents that read AGENTS.md |
| `CLAUDE.md` | Claude Code (imports AGENTS.md) |

If your app already has an `AGENTS.md` or `CLAUDE.md`, merge the content in instead of overwriting it.
