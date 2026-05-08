# AI Host Deployment

## Scope
Route AI host deploy, validation, and rollback work to the canonical task namespaces. Do not invent new flows; follow the namespaces described here.

## Canonical task surfaces
- Host lifecycle (build/plan/apply/deploy/logs/rollback) belongs to `infra:*` (e.g., `infra:deploy:host:<host>`, `infra:logs:host:<host>`, `infra:rollback:host:<host>`).
- Validation checks run via `checks:*` (`checks:nullclaw:smoke:<host>` for nullclaw deployments).
- Operator helpers for AI services use `agents:xs:*` and `agents:oauth:*` tasks.

## Host exceptions
When a host has operational nuance, consult `.agents/deploy/hosts/<host>.md` before making assumptions.

## What not to assume
- Do not treat `.agents/*` as executable truth; only the Taskfiles (`taskfiles/*.yml`) define workflows.
- Prefer canonical `infra:*` and `dev:*` tasks over legacy `services:*` wrappers for new workflows.
