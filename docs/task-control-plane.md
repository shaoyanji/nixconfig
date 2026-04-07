# Task Control Plane

This repository uses a small control-plane namespace policy so task names stay predictable and easier to review.

## Groups

- `infra`: host/deploy/rebuild/switch/boot operations
- `services`: AI-host validation/evidence/drift/promotion/status flows plus compatibility wrappers
- `checks`: validation and narrow verification
- `agents`: interactive/operator menus and handoff helpers
- `dev`: git/build/local workflows

## Naming Rules

- Prefer namespaced tasks for any new canonical entrypoint.
- Keep top-level tasks only for operator-facing entrypoints and legacy wrappers.
- Put host rebuild and deployment flows under `infra:*`.
- Put AI-host validation/evidence/drift/promotion/status flows (and compatibility wrappers) under `services:*`.
- Put menus, grouped help, grouped status, and handoff helpers under `agents:*`.
- Put validation under `checks:*`.
- Put git, flake update, site/static target workflows, and local developer workflows under `dev:*`.

## Canonical surfaces

- Host lifecycle/deploy/log flows live in `taskfiles/infra.yml` under the `infra:*` namespace.
- AI evidence, drift, status, and promotion flows remain under `services:*` via `taskfiles/services-ai-hosts.yml`; the `services:validate:host:*` and related wrappers stay there for AI-host continuity.
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` now only expose the minimal compatibility wrappers operators still need to reach the canonical AI-host/deploy flows.
- Validation/check flows live in `taskfiles/checks.yml`; dev/git helpers (including the flake-update helpers) live in `taskfiles/dev.yml`.
- Agent/operator helpers live in `taskfiles/agents.yml` and query `taskfiles/ai-host-manifest.json` for AI-host metadata, including the `agents:xs:*` wrappers that drive `scripts/task/xs-helper.sh`.

## Controls
- Prefer new `infra:*` names for any host-local deployments, rebuilds, or logs; the old `services:*` wrappers are retained only for compatibility.
- Keep menus and helper shells under `agents:*`.
- Keep validation under `checks:*`.
- Keep git/flake/local workflows under `dev:*`.

## Services layering

`taskfiles/services.yml` now only includes the split surfaces:
- `taskfiles/services-core.yml` exposes the remaining `services:*` compatibility entrypoints for AI hosts and deploy aliases while routing work toward the canonical namespaces.
- `taskfiles/services-ai-hosts.yml` remains the canonical home for AI evidence/drift/status/promotion flows.
- `taskfiles/services-legacy.yml` holds the small set of legacy convenience menus and host deploy aliases that operators still reach for.

Operator menus that list AI hosts now read `taskfiles/ai-host-manifest.json` via `scripts/task/ai-host-manifest.sh` instead of embedding host names directly.
