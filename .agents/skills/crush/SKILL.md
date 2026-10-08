---
name: crush
description: "Delegate coding to Crush CLI (Charm's AI coding agent). Uses --yolo and structured output flags."
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Crush, Charm, AI-Agent, Delegation]
    related_skills: [antigravity, codex, hermes-agent]
---

# Crush CLI

Delegate coding tasks to [Crush](https://github.com/charmbracelet/crush) via the Hermes terminal. Crush is CharmBracelet's terminal AI coding agent (spiritual successor to OpenCode).

## When to use

- Building features
- Refactoring
- PR reviews
- Batch issue fixing
- TUI-based coding sessions

Requires the crush CLI.

## Prerequisites

- Crush installed: `npm install -g @charmland/crush` or via nix: `nix shell nixpkgs#crush`
- Google auth configured: `crush auth` (OAuth flow via browser)
- Must run inside a git repository — Crush requires git context
- Use `pty=true` in terminal calls — Crush is an interactive terminal app

## Key Flags

| Flag | Description |
|------|-------------|
| `-y` / `--yolo` | Auto-accept all permissions (dangerous; use with care). **Crush cannot do sudo** — use this flag for delegation |
| `--continue` | Continue the most recent session |
| `--session <id>` | Continue a specific session |
| `--quiet` | Hide the spinner |
| `--verbose` | Show logs |
| `--reasoning-effort <level>` | Set reasoning effort (high/medium/low) |

## One-Shot Tasks

```bash
terminal(command="crush run --yolo 'Add dark mode toggle to settings'", workdir="~/project", pty=true)
```

For scratch work:
```bash
terminal(command="cd $(mktemp -d) && git init && crush run --yolo 'Build a snake game in Python'", pty=true)
```

## Background Mode (Long Tasks)

```bash
# Start in background with PTY
terminal(command="crush run --yolo --verbose 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
# Returns session_id

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send input if Crush asks a question
process(action="submit", session_id="<id>", data="yes")

# Kill if needed
process(action="kill", session_id="<id>")
```

## Verification Protocol

Before deploying, always verify:
1. `git status` is clean
2. `git diff` shows only intended changes
3. Tests pass: `pytest` or equivalent
4. No untracked secrets in workspace

## Rules

1. **Always use `--yolo`** for agent execution — this is the standard delegation mode (auto-accepts all permissions)
2. **Use `--continue`** to pick up where Crush left off
3. **Always use `pty=true`** — Crush is an interactive terminal app and hangs without a PTY
4. **Git repo required** — Crush won't run outside a git directory. Use `mktemp -d && git init` for scratch work
5. **Don't interfere** — monitor with `poll`/`log`, be patient with long-running tasks
6. **Always clean up** — kill background processes, remove temp directories, and verify workspace hygiene
