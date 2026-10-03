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

If your app already has an `AGENTS.md` or `CLAUDE.md`, merge the content in instead of overwriting it.

## What you get

| File | Read by |
| --- | --- |
| [`.github/copilot-instructions.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/.github/copilot-instructions.md) | GitHub Copilot, for every request |
| [`.github/instructions/*.instructions.md`](https://github.com/{{ site.repository }}/tree/{{ site.branch }}/instructions/.github/instructions) | GitHub Copilot, for files matching each `applyTo` glob |
| [`AGENTS.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/AGENTS.md) | Codex, Cursor, Jules and other agents that read `AGENTS.md` |
| [`CLAUDE.md`](https://github.com/{{ site.repository }}/blob/{{ site.branch }}/instructions/CLAUDE.md) | Claude Code (imports `AGENTS.md`) |

The area files are:

| File | Applies to |
| --- | --- |
| `models.instructions.md` | `app/models/**` |
| `controllers.instructions.md` | `app/controllers/**`, `config/routes.rb` |
| `views.instructions.md` | `app/views/**`, `app/helpers/**`, `app/javascript/**` |
| `jobs.instructions.md` | `app/jobs/**`, `app/mailers/**` |
