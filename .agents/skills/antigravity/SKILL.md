---
name: antigravity
description: "Delegate coding to Antigravity CLI (Google's AI agent). Uses --dangerously-skip-permissions and --jsonschema flags."
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Antigravity, Google, AI-Agent, Delegation]
    related_skills: [claude-code, hermes-agent]
---

# Antigravity CLI

Delegate coding tasks to [Antigravity](https://antigravity.google/) via the Hermes terminal. Antigravity is Google's autonomous coding agent CLI.

## When to use

- Building features
- Refactoring
- PR reviews
- Batch issue fixing
- Ultra-fast web automation with browser integration

Requires the antigravity CLI.

## Prerequisites

- Antigravity installed: `npm install -g antigravity-cli` or via nix: `nix shell nixpkgs#antigravity-cli`
- Google auth configured: `antigravity auth` (OAuth flow via browser)
- Must run inside a git repository — Antigravity requires git context
- Use `pty=true` in terminal calls — Antigravity is an interactive terminal app

## Key Flags

| Flag | Description |
|------|-------------|
| `--dangerously-skip-permissions` (or `-p`) | Skip permission checks for faster execution |
| `--jsonschema` | Enforce structured JSON output for agent integration |
| `--sandbox danger-full-access` | Full access sandbox mode |

## One-Shot Tasks

```bash
terminal(command="antigravity --dangerously-skip-permissions --jsonschema 'Add dark mode toggle to settings'", workdir="~/project", pty=true)
```

For scratch work:
```bash
terminal(command="cd $(mktemp -d) && git init && antigravity --dangerously-skip-permissions --jsonschema 'Build a snake game in Python'", pty=true)
```

## Background Mode (Long Tasks)

```bash
# Start in background with PTY
terminal(command="antigravity --dangerously-skip-permissions --jsonschema --sandbox danger-full-access 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
# Returns session_id

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send input if Antigravity asks a question
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

1. **Always use `--dangerously-skip-permissions`** (`-p`) for agent execution — this is the standard delegation mode
2. **Always include `--jsonschema`** for structured output and agent integration
3. **Always use `pty=true`** — Antigravity is an interactive terminal app and hangs without a PTY
4. **Git repo required** — Antigravity won't run outside a git directory. Use `mktemp -d && git init` for scratch work
5. **Use `--sandbox danger-full-access`** for building tasks — avoids sandbox break issues
6. **Don't interfere** — monitor with `poll`/`log`, be patient with long-running tasks
7. **Always clean up** — kill background processes, remove temp directories, and verify workspace hygiene
8. **Never install via profile** — never use `npm install -g` or profile-based installations; use `nix shell` for on-demand binaries
