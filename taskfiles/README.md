# Taskfile Map

## Scope
Quick reference to who owns each taskfile and where to go for lifecycle, AI-host, and agent queries after the infra/services/agents cleanup.

## Canonical ownership
- `Taskfile.yml` is the root; it pulls in the taskfiles and holds a handful of top-level helpers (`deploy`, `logs`, `status`, etc.). It is not where the substantive logic lives.
- `taskfiles/infra.yml` hosts canonical lifecycle and host-control operations (`infra:*`). Treat it as the source for rebuild/switch/boot/deploy/rollback/log flows.
- `taskfiles/services-ai-hosts.yml` owns specialized AI-host evidence, drift, status, and promotion flows (`services:evidence:*`, `services:drift:*`, `services:status:*`, `services:promote:*`).
- `taskfiles/services-core.yml` is now a compatibility wrapper layer that re-exports the historical `services:*` lifecycle commands while delegating to the new `infra:*` tasks.
- `taskfiles/services-legacy.yml` keeps legacy shortcuts, host deploy menus, and alias commands that keep operator muscle memory intact.
- `taskfiles/agents.yml` contains interactive/agent helpers and now includes the `agents:hosts:*` wrappers that call the manifest helper script.

## File-by-file map
- `Taskfile.yml` – include root, top-level menus, and a few operator entrypoints (`deploy`, `logs`, `status`). Canonical: entrypoint only.
- `taskfiles/infra.yml` – canonical host lifecycle surface (`infra:rebuild:*`, `infra:switch:*`, `infra:boot:*`, `infra:deploy:host:*`, `infra:rollback:*`, `infra:logs:*`, deploy/log menus). Source truth for host control.
- `taskfiles/services-core.yml` – compatibility wrappers for the legacy `services:*` lifecycle commands; delegates to `infra:*` except for validation/evidence logic that stays under `services:*`.
- `taskfiles/services-ai-hosts.yml` – owner of AI evidence/drift/status/promotion tasks plus fleet checks references. Canonical for AI validation work.
- `taskfiles/services-legacy.yml` – legacy convenience surface (menus, host shortcuts, backward-compatible deploy/log menus) that call into `services:*` wrappers or the canonical infra menus.
- `taskfiles/agents.yml` – agent/operator helpers and the new `agents:hosts:*` wrappers that call the manifest helper script for list/show/services/paths/tasks.

## Truth boundaries
- `taskfiles/ai-host-manifest.json` is the AI-host metadata source; the helper script `scripts/task/ai-host-manifest.sh` queries it and surfaces derived task names.
- `scripts/task/*` provide implementation helpers (evidence/drift/promotion scripts, manifest helper, secret utilities) but are not the primary task surface.
- `AGENTS.md` and `.agents/*` are guidance/routing; they explain where to find workflows but do not execute or redefine them.

## Compatibility layers
- Legacy `services:*` names exist in `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` for operator continuity; they mostly defer to `infra:*` now.
- Use `taskfiles/agents.yml` wrappers for quick manifest queries rather than editing JSON by hand.

## Common "where do I look?"
- Need lifecycle/deploy work → `taskfiles/infra.yml` (`infra:*`).
- Need AI evidence/drift/promotion→ `taskfiles/services-ai-hosts.yml` (`services:evidence:*`, `services:drift:*`, `services:promote:*`).
- Need manifest-aware host info → `taskfiles/ai-host-manifest.json` via `scripts/task/ai-host-manifest.sh` or `task agents:hosts:*`.
- Need compatibility aliases/menus → `taskfiles/services-core.yml` (wrappers) or `taskfiles/services-legacy.yml` (shortcuts).
- Need agent/operator guidance → `AGENTS.md` plus `.agents/deploy/*.md`.

## What not to assume
- Don’t assume `Taskfile.yml` contains the lifecycle logic—open the individual taskfiles instead.
- Don’t assume AI host metadata is duplicated elsewhere; use the manifest/helper.
- Don’t treat `.agents/*` as executable truth; tasks still live in the Taskfiles.
