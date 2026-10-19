# Rollback Routing

## Scope
Explain rollback in terms of the existing `infra:*` tasks without creating new procedures.

## Canonical tasks
- Inspect generations (flake revisions + current marker): `task infra:generations` or `task infra:generations:host:<host>`
- Apply rollback over SSH: `task infra:rollback:apply:host:<host>`
- Canonical rollback alias: `task infra:rollback:host:<host>` (reruns apply step)
- Post-rollback validation: `task services:validate:host:<host>` (systemd state over SSH)

## What not to assume
- `.agents/*` is not executable truth; only Taskfiles define workflows.
- Prefer `infra:*` tasks over legacy `services:*` wrappers for rollbacks.
- **NEVER inspect generations with raw `ls /nix/var/nix/profiles/`**: standard `ls` sorts alphabetically, making `system-99-link` sort after `system-157-link` and misleading operators into rolling back dozens of generations into the past. Always use `task infra:generations` or `nixos-rebuild list-generations`.
