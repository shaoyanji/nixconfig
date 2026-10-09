---
name: antigravity
description: "Delegate coding to agy CLI (Google agent, v1.2.16). Uses --dangerously-skip-permissions, --json-schema <path>, --print='<prompt>', --mode plan, --output-format json. Binary NOT migrated; only invocation reference persisted."
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

- `agy` installed: binary at `/etc/profiles/per-user/devji/bin/agy` (v1.2.16). NOT installed in this repo; binary NOT migrated into git-controlled parts.
- NOT installed via `npm install -g antigravity-cli` (different binary name).
- No Google OAuth (`antigravity auth`) required for `agy` CLI operation.
- Must run inside a git repository (`/tmp/antigravity_task` used as scratch workspace).
- Use `pty=true` in terminal calls — `agy` hangs without PTY.

## Key Flags

| Flag | Description |
|------|-------------|
|| `--dangerously-skip-permissions` (`-p`) | Skip permission checks |
|| `--json-schema <path>` | JSON schema file path (NOT bare `--jsonschema`) |
|| `--print='<prompt>'` | Non-interactive prompt |
|| `--mode plan` | Planning mode |
|| `--output-format json` | Structured JSON output |
|| `--sandbox` | Sandbox mode (syntax may differ from old `--sandbox danger-full-access`) |

## One-Shot Tasks

```bash
# Verified syntax for agy v1.2.16 (NOT antigravity binary)
terminal(command="agy --dangerously-skip-permissions --json-schema /tmp/antigravity_task/schema.json --print='Add dark mode toggle to settings' --mode plan --output-format json", workdir="~/project", pty=true)
```

For scratch work (requires `.git` directory):
```bash
terminal(command="cd $(mktemp -d) && git init && agy --dangerously-skip-permissions --print='Build a test script' --mode plan --output-format json", workdir="/tmp/project", pty=true)
```

## Background Mode (Long Tasks)

```bash
# Background mode (verified syntax for agy v1.2.16; binary NOT migrated)
terminal(command="agy --dangerously-skip-permissions --json-schema /tmp/antigravity_task/schema.json --print='Process email judgments' --mode plan --output-format json", workdir="~/project", background=true, pty=true)
# Note: previous session proc_60c8a2ea9699 completed exit=0 but produced truncated/no artifact (syntax fixed after .hm-backup patch).
# Monitor progress (process_manage may not be available in all Hermes sessions; verify with ps/log if needed):
# process(action="poll", session_id="<id>")
# process(action="log", session_id="<id>")

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send input if Antigravity asks a question
process(action="submit", session_id="<id>", data="yes")

# Kill if needed
process(action="kill", session_id="<id>")
```

## Verification Protocol (required before mailbox mutation)

Before deploying any archive/deletion action:
1. Read `HANDOFF.md` at `/home/devji/.hermes/cache/scratch/email-cleansing/HANDOFF.md`.
2. Confirm `jev-decide` criteria include `archive` and `delete` choices (not just `archive`/`keep`).
3. Confirm `mailbox_mutation_performed` is `false` before execution; set to `true` only after verified `himalaya` command success.
4. Confirm user authorization is recorded (this session: user authorized via Telegram DM, message IDs 1445, 1448, 1458).
5. `git status` clean (this skill directory only; binary not migrated).
6. No untracked secrets in workspace (`~/.config/hermes/hermes.env` carries `JISIFU_APP_PASSWORD` via sops, not committed).
7. Verify with `himalaya -a jisifu envelope list` before and after mutation to confirm change.
8. Report execution result honestly: include exit codes, applied counts, and any syntax errors (e.g., `--mailbox Archive` unavailable in Gmail IMAP).

## Rules

1. **Always verify `agy --help` before invoking** — `--dangerously-skip-permissions` and `--json-schema <path>` are confirmed; `--jsonschema` (bare) does NOT work on `agy` v1.2.16.
2. **Always include `--json-schema <path>`** for structured output; never use bare `--jsonschema`.
3. **Always use `--print='<prompt>'`** for non-interactive delegation; never pass unquoted prompts that can be interpreted as flags.
4. **Always run inside `git` directory** — `agy` fails outside `.git` (`/tmp/antigravity_task` scratch workspace verified).
5. **Always check `HANDOFF.md`** before mailbox mutation; confirm authorization recorded.
6. **Always confirm `mailbox_mutation_performed`** explicitly (`false` before, `true` only after verified `himalaya` success).
7. **Always report execution honestly** (exit codes, applied counts, syntax errors, timeout results — e.g., previous `proc_60c8a2ea9699` completed exit=0 with truncated/no artifact).
8. **Always clean up** — kill `proc_*` background sessions (verify with `ps` or `notify_on_complete`); remove temp directories.
9. **Never migrate binary** — `agy` (`/etc/profiles/per-user/devji/bin/agy`, v1.2.16) stays in profile; this skill only defines invocation patterns.
