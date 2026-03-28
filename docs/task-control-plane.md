# Task Control Plane

This repository uses a small control-plane namespace policy so task names stay predictable and easier to review.

## Groups

- `infra`: host/deploy/rebuild/switch/boot operations
- `services`: daemon/service lifecycle operations
- `checks`: validation and narrow verification
- `agents`: interactive/operator menus and handoff helpers
- `dev`: git/build/local workflows

## Naming Rules

- Prefer namespaced tasks for any new canonical entrypoint.
- Keep top-level tasks only for operator-facing entrypoints and legacy wrappers.
- Put host rebuild and deployment flows under `infra:*`.
- Put daemon and service lifecycle flows under `services:*`.
- Put menus, grouped help, grouped status, and handoff helpers under `agents:*`.
- Put validation under `checks:*`.
- Put git, flake update, site sync, and local developer workflows under `dev:*`.

## Canonical surfaces

- Host lifecycle/deploy/log flows live in `taskfiles/infra.yml` and expose the `infra:*` namespace.
- AI evidence, drift, status, and promotion flows remain under `services:*` via `taskfiles/services-ai-hosts.yml`; the `services:validate:host:*` and related wrappers are routed through this file.
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` keep the legacy `services:*` entrypoints but delegate almost all work back into the canonical namespaces.
- Validation/check flows live in `taskfiles/checks.yml`; dev/git helpers (including the new flake-update helpers) live in `taskfiles/dev.yml`.
- Agent/operator helpers live in `taskfiles/agents.yml` and query `taskfiles/ai-host-manifest.json` for AI-host metadata.

## Controls
- Prefer new `infra:*` names for any host-local deployments, rebuilds, or logs; the old `services:*` wrappers are retained only for compatibility.
- Keep menus and helper shells under `agents:*`.
- Keep validation under `checks:*`.
- Keep git/flake/local workflows under `dev:*`.

## Services layering

`taskfiles/services.yml` now only includes the split surfaces:
- `taskfiles/services-core.yml` exposes the historical `services:*` host tasks while delegating the actual work to `infra:*` or the AI services files.
- `taskfiles/services-ai-hosts.yml` remains the canonical home for AI evidence/drift/status/promotion flows.
- `taskfiles/services-legacy.yml` holds the legacy convenience menus and aliases operators rely on.

Operator menus that list AI hosts now read `taskfiles/ai-host-manifest.json` via `scripts/task/ai-host-manifest.sh` instead of embedding host names directly.
