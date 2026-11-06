---
name: crush
description: "DEPRECATED 2026-11-06 — do not delegate to Crush. Its free credits are exhausted. Use agy (Tier 1), freebuff-headless (Tier 2) or hermes (Tier 3) instead; this page is kept so an old reference lands on the explanation."
version: 0.2.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Deprecated, Crush, Charm, Coding-Agent]
    related_skills: [antigravity, hermes-agent, frieren-offload, reasonix]
---

# Crush — retired

Crush is no longer part of this fleet. The free credits that made it the last
cascade tier are gone, so a call to it burns a turn and fails rather than doing
work. Do not install it, do not add it to a cascade, and do not offer it as an
alternative.

## What to use instead

| Need | Agent |
| :--- | :--- |
| first tier — one-shot or interactive coding | `agy` (`nix run github:numtide/llm-agents.nix#antigravity-cli`) |
| second tier — zero-prompt batch work | `freebuff-headless -C <dir> -t <seconds> "<prompt>"` |
| third tier — fleet persona with tools | `hermes chat -q "<prompt>" --oneshot -Q --run-budget 600` |
| a different third-party agent | `reasonix`, `opencode`, `claude-code`, `codex` (see `nix-toolchain`) |

The tier order and the verified flags for each live in the `frieren-offload`
skill and `hosts/frieren/infra-stack.nix` (`run_agent_cascade`), which no longer
carries a Crush step.

## Why the page still exists

`skill: crush` is written into older sessions, handoffs and history notes. Keeping
a stub means that reference resolves to "retired, use agy" instead of a usage
guide that would send an agent at a dead quota.
