# Taskfile Map

## Scope
Quick reference to who owns each taskfile and where to go for lifecycle, deployment, and operator queries.

## Canonical ownership
- `Taskfile.yml` is the entrypoint; it loads the shards and hosts top-level helper menus (`deploy`, `logs`, `status`, `menu`).
- `taskfiles/infra.yml` is the canonical host lifecycle surface (`infra:*`) for plan/apply/deploy/rollback/logs and secrets management.
- `taskfiles/agents.yml` holds operator helpers, xs runtime wrappers, and OAuth/session management.
- `taskfiles/checks.yml` contains validation and smoke checks (primarily nullclaw deployment validation).
- `taskfiles/dev.yml` contains git/flake/local helper workflows, including site build/preview/deploy tasks.
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` provide legacy compatibility wrappers routing to canonical `infra:*` tasks.

## File-by-file map
- `Taskfile.yml` – entrypoint with top-level menus
- `taskfiles/infra.yml` – host lifecycle, secrets, SOPS operations
- `taskfiles/agents.yml` – operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml` – validation and smoke checks
- `taskfiles/dev.yml` – git workflows, flake updates, site deployment
- `taskfiles/services-core.yml` – minimal compatibility wrappers
- `taskfiles/services-legacy.yml` – deprecated aliases (marked `[deprecated]`)

## Truth boundaries
- `taskfiles/site-manifest.json` is the site/static deployment metadata source; query it through `scripts/task/site-target.sh` or `dev:site:*` wrappers.
- `scripts/task/*` are helper implementations only.
- `AGENTS.md` and `.agents/*` document routing/guidance; they do not execute.

## Common "where to look"
- Host deployment/lifecycle → `taskfiles/infra.yml` (`infra:*`)
- Operator helpers and xs/OAuth → `taskfiles/agents.yml` (`agents:xs:*`, `agents:oauth:*`)
- Validation checks → `taskfiles/checks.yml` (`checks:*`)
- Git/flake workflows, site deployment → `taskfiles/dev.yml` (`dev:*`)
- Legacy compatibility → `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml`

## What not to assume
- Don't assume `Taskfile.yml` contains the lifecycle logic—open the individual taskfiles instead.
- Don't treat `.agents/*` as executable truth; tasks still live in the Taskfiles.
- Don't use `services:*` tasks for new workflows; prefer canonical `infra:*` or `dev:*` namespaces.