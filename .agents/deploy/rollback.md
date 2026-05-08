# Rollback Routing

## Scope
Explain rollback in terms of the existing `infra:*` tasks without creating new procedures.

## Canonical tasks
- Apply rollback over SSH: `task infra:rollback:apply:host:<host>`
- Canonical rollback alias: `task infra:rollback:host:<host>` (reruns apply step)
- Post-rollback validation: `task checks:nullclaw:smoke:<host>` for nullclaw hosts

## What not to assume
- `.agents/*` is not executable truth; only Taskfiles define workflows.
- Prefer `infra:*` tasks over legacy `services:*` wrappers for rollbacks.
