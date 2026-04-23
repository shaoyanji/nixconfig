# Taskfile Map

## Scope
Quick reference to who owns each taskfile and where to go for lifecycle, AI-host, and agent queries after the infra/services/agents cleanup.

## Canonical ownership
- `Taskfile.yml` is the entrypoint; it loads the shards and hosts only a few top-level helper menus (`deploy`, `logs`, `status`).
- `taskfiles/infra.yml` is the canonical host lifecycle surface (`infra:*`).
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` keep the legacy `services:*` compatibility wrappers while routing the work to the canonical namespaces.
- `taskfiles/dev.yml` contains git/flake/local helper workflows, including site build/preview/deploy tasks.
- `taskfiles/agents.yml` holds operator helper wrappers and xs/oauth commands.

## File-by-file map
- `Taskfile.yml` – entrypoint/menus only.
- `taskfiles/infra.yml` – host lifecycle/deploy/log flows.
- `taskfiles/services-*` – compatibility wrappers and validation surfaces.
- `taskfiles/dev.yml` – git/flake helpers plus site build/preview/deploy flows.
- `taskfiles/agents.yml` – operator helpers, xs, and oauth wrappers.

## Truth boundaries
- `taskfiles/site-manifest.json` is the site/static deployment metadata source; query it through `scripts/task/site-target.sh` or `dev:site:*` wrappers.
- `scripts/task/*` are helper implementations only.
- `AGENTS.md` and `.agents/*` document routing/guidance; they do not execute.

## Common "where to look"
- Lifecycle/deploy/log flows → `taskfiles/infra.yml` (`infra:*`).
- Host validation → `taskfiles/services-core.yml` (`services:validate:host:*`).
- Flake/git helpers, site local preview/deploy, and `bountystash` updates → `taskfiles/dev.yml`.
- Need to update the `bountystash` flake input? use `dev:flake:update:bountystash`.
- Legacy `services:*` aliases → `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml`.
- Operator helpers and xs lookups → `taskfiles/agents.yml` and `scripts/task/site-target.sh`, including the `agents:xs:*` wrappers for `xs-helper`.
- Service-user OAuth/session management → `taskfiles/agents.yml` (`agents:oauth:*`), implemented by `scripts/task/service-oauth.sh`.

## What not to assume
- Don’t assume `Taskfile.yml` contains the lifecycle logic—open the individual taskfiles instead.
- Don’t treat `.agents/*` as executable truth; tasks still live in the Taskfiles.
