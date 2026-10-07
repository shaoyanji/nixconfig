---
name: ai-memory
description: "Cross-agent memory via ai-memory (wiki + SQLite)."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [memory, ai-memory, sqlite, mcp]
    related_skills: []
---

# `ai-memory` — Shared Agent Memory Store

Long-term memory for coding agents: a flat-file wiki (`wiki/`) indexed into
SQLite (FTS5), capturable from agent sessions, exposed over stdio/HTTP MCP.
The DB is rebuildable from the markdown files at any time (`reindex`).

## 1. Layout

- Data dir: `~/.ai-memory/` (config: `~/.ai-memory/config.toml`)
- Wiki pages live as markdown under `wiki/<workspace>/<project>/`
- Backups: `ai-memory backup` → gzipped tarball of wiki/ + db/ + config.toml

## 2. First-time setup

```bash
ai-memory init      # create the data directory layout
ai-memory status    # counts, paths, version
ai-memory doctor    # check which agent harnesses are hooked/captured
ai-memory backfill  # import existing local session history once (mid-project install)
```

## 3. Wiki operations (what agents call most)

```bash
ai-memory write-page --path decisions/pxe-setup "..."   # write/update + index
ai-memory search "iventoy dhcp mode"                    # FTS5 full-text search
ai-memory read-page decisions/pxe-setup                 # exact path
ai-memory read-page "how did we fix nginx"              # search + top hit
```

Convention for pages: `decisions/`, `runbooks/`, `postmortems/`, `projects/<name>/`.
Write a page after any non-trivial fix or decision — this is the cross-agent
handoff medium (replaces the old OpenClaw mem0 TOON tier).

## 4. Cross-agent handoffs & messaging

```bash
ai-memory handoffs                 # list open handoffs (cancel stale by id)
ai-memory message send ...         # directed mailbox between projects
ai-memory workstreams              # managed workstreams for this checkout
ai-memory run <agent-cmd>          # launch agent inside a managed workstream
ai-memory continue                 # resume most recent managed checkout
```

## 5. MCP server (for hermes / Zed / any MCP client)

```bash
ai-memory serve                    # stdio MCP (default)
ai-memory serve --http ...         # HTTP mode
```

Zed (`~/.config/zed/settings.json` → `context_servers`):
```json
{ "command": "/run/current-system/sw/bin/ai-memory", "args": ["serve"] }
```
Hermes: `hermes mcp add ai-memory -- /run/current-system/sw/bin/ai-memory serve`
(or the interactive equivalent in `hermes mcp`).

## 6. Hygiene

- `ai-memory audit-contamination` — find sessions/pages attributed to the
  wrong project (run after big refactors of the data dir).
- `ai-memory compact` — reclaim DB pages; `ai-memory reset` — nuke wiki+db
  (destructive; `backup` first).
- Restore onto a new machine: `ai-memory restore <tarball>` then `reindex`.
