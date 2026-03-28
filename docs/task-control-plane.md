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

## Current Canonical Examples

- `infra:rebuild:nixos`
- `infra:rebuild:darwin`
- `infra:rebuild:home-manager`
- `infra:switch:nixos`
- `infra:boot:nixos`
- `infra:deploy:host:<host>`
- `services:logs:host:<host>`
- `checks:quick`
- `agents:menu`
- `agents:help`
- `agents:status`
- `dev:git:quick-push`

## Legacy Compatibility

Legacy task names remain available as wrappers. New docs and scripts should prefer the canonical namespaced tasks so future additions do not drift back into mixed namespaces.

## Services Layering

`taskfiles/services.yml` is now a thin include layer split by concern:
- `taskfiles/services-core.yml`: canonical service/deploy/rebuild/log flows
- `taskfiles/services-ai-hosts.yml`: AI host evidence/drift/status/promotion workflows
- `taskfiles/services-legacy.yml`: compatibility aliases and menus

Operator menus that enumerate AI hosts now derive host lists from `taskfiles/ai-host-manifest.json` instead of hardcoded host names.
