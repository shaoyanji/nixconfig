# Rollback Routing

## Scope
Explain rollback in terms of the existing infra/ services tasks without creating new procedures.

## Canonical tasks
- Apply rollback over SSH: `infra:rollback:apply:host:*`.
- Canonical rollback alias for hosts: `infra:rollback:host:*` (it just reruns the apply step).
- Post-rollback validation and evidence still run via `services:validate:host:*` and `services:evidence:rollback:host:*`.

## Helper guidance

## What not to assume
- There is no new rollback workflow in `.agents/*`; stick to the `infra`/`services` tasks defined in the Taskfiles.
