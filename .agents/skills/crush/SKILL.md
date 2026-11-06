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

Crush is no longer part of this fleet: the free credits that made it the last
cascade tier are gone, so a call burns a turn and fails rather than doing work.
Do not install it, do not add it to a cascade, do not offer it as an alternative.

`skill: crush` is written into older sessions, handoffs and history notes, so
this page stays to land that reference on "retired" instead of a usage guide
that would send an agent at a dead quota. The cascade that replaced it, with its
tier order and verified flags, is the `frieren-offload` skill and
`hosts/frieren/infra-stack.nix` (`run_agent_cascade`), which no longer carries a
Crush step.
