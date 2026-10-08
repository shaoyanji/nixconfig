---
name: reasonix
description: "Delegate coding/analysis to reasonix (numtide's multi-model coding agent). Headless -p mode with JSON output; falls back to nix shell github:numtide/llm-agents.nix#reasonix when not installed."
version: 0.1.0
author: Shaoyan Ji (shaoyanji)
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [Coding-Agent, Reasonix, AI-Agent, Delegation]
    related_skills: [crush, dev, agents]
---

# reasonix — coding-agent delegation

Delegate repository analysis and coding tasks to [reasonix](https://github.com/numtide/reasonix), numtide's config- and plugin-driven multi-model coding agent. Use it when you want a second opinion, a repository summary, or a structured hand-off instead of doing the analysis inline.

## When to use

- Summarizing an unfamiliar repository before planning work
- Delegating a self-contained coding task with structured (JSON) output to parse
- Getting a model's review of local diffs (`reasonix review`)

## Availability

`reasonix` may **not** be on PATH. Check first:

```bash
command -v reasonix
```

If it is unavailable, run it straight from numtide's flake (no install needed):

```bash
nix shell github:numtide/llm-agents.nix#reasonix --command reasonix --version
```

## Usage

### Headless task with JSON output (primary interface)

```bash
reasonix -p "summarize this repository" --output-format json
```

Fallback form when not installed:

```bash
nix shell github:numtide/llm-agents.nix#reasonix \
  --command reasonix -p "summarize this repository" --output-format json
```

`-p` / `--print` runs the task non-interactively and exits; `--output-format`
accepts `text`, `json`, or `stream-json` (use `json` when you need to parse the
result, `stream-json` for incremental consumption).

### Other useful modes

```bash
# Interactive TUI session
reasonix

# Structured events as JSONL (step-by-step, redacted)
reasonix run --events-jsonl "fix the failing tests"

# AI code review of local diffs / a specific commit
reasonix review
reasonix review --commit <sha>

# Diagnostics (redacted) if something misbehaves
reasonix doctor --json
```

## Notes

- Model selection: `--model NAME` on any invocation.
- Permission gating for non-interactive runs: `--permission-mode MODE` (used with `-p` / `run`).
- `reasonix` is a prebuilt package from `github:numtide/llm-agents.nix`; cache hits only when our nixpkgs matches theirs, otherwise it builds locally from source.
