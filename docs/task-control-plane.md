# Task Control Plane

This repository uses a small control-plane namespace policy so task names stay predictable and easier to review.

## Groups

- `infra`: host/deploy/rebuild/switch/boot operations
- `services`: host validation and compatibility wrappers
- `checks`: validation and narrow verification
- `agents`: interactive/operator menus and handoff helpers
- `dev`: git/build/local workflows

## Naming Rules

- Prefer namespaced tasks for any new canonical entrypoint.
- Keep top-level tasks only for operator-facing entrypoints and legacy wrappers.
- Put host rebuild and deployment flows under `infra:*`.
- Put host validation flows (and compatibility wrappers) under `services:*`.
- Put menus, grouped help, grouped status, and handoff helpers under `agents:*`.
- Put validation under `checks:*`.
- Put git, flake update, site/static target workflows, and local developer workflows under `dev:*`.

## Canonical surfaces

- Host lifecycle/deploy/log flows live in `taskfiles/infra.yml` under the `infra:*` namespace.
- Host validation lives under `services:*` via `taskfiles/services-core.yml`; the `services:validate:host:*` and related wrappers stay there for continuity.
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` now only expose the minimal compatibility wrappers operators still need to reach the canonical deploy flows.
- Validation/check flows live in `taskfiles/checks.yml`; dev/git helpers (including the flake-update helpers) live in `taskfiles/dev.yml`.
- Agent/operator helpers live in `taskfiles/agents.yml`, including the `agents:xs:*` wrappers that drive `scripts/task/xs-helper.sh`.

## Controls
- Prefer new `infra:*` names for any host-local deployments, rebuilds, or logs; the old `services:*` wrappers are retained only for compatibility.
- Keep menus and helper shells under `agents:*`.
- Keep validation under `checks:*`.
- Keep git/flake/local workflows under `dev:*`.

## Services layering

`taskfiles/services.yml` now only includes the split surfaces:
- `taskfiles/services-core.yml` exposes the remaining `services:*` compatibility entrypoints and deploy aliases while routing work toward the canonical namespaces.
- `taskfiles/services-legacy.yml` holds the small set of legacy convenience menus and host deploy aliases that operators still reach for.
