# AGENTS.md

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `taskfiles/README.md` for ownership and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth.

## Task Namespace Summary
See [Task Control Plane](docs/task-control-plane.md) for full namespace definitions and workflow examples.

## Git Hooks Setup
This repo includes pre-commit hooks in `.githooks/` to catch common issues:
- `check-docs.sh`: Detects broken absolute paths in documentation

To enable: `bash .git-hooks-setup.sh` (sets `core.hooksPath` to `.githooks/`)

## Key Operator Helpers

- `agents:xs:*` wrappers run `scripts/task/xs-helper.sh` against local and service stores for artifact, contract, record, and trace work
- `agents:oauth:*` wrappers run `scripts/task/service-oauth.sh` with correct `HOME` and `XDG_*` environment for each service user
- NAS client recovery logic lives under `modules/profiles/nas-client.nix`

## Deployment Guidance

Host deployment flows use `infra:*` tasks directly:
- `infra:plan:host:<host>` - Build/evaluate host closure
- `infra:apply:host:<host>` - Apply configuration to remote host
- `infra:deploy:host:<host>` - Plan + apply + validate
- `infra:rollback:host:<host>` - Roll back to previous generation

See `.agents/deploy/README.md` for host-specific deployment notes.
