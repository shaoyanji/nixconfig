# AI Host Deployment

## Scope
Route AI host deploy, validate, evidence, drift, and promotion work to the existing manifest and taskfiles. Do not invent new flows; follow the namespaces described here.

## Manifest truth
- `taskfiles/ai-host-manifest.json` is the single source of AI host metadata.
- Use `scripts/task/ai-host-manifest.sh` or `task agents:hosts:*` to answer host/service/promotion questions without editing JSON by hand.

## Canonical task surfaces
- Host lifecycle (build/plan/apply/deploy/logs/rollback) belongs to `infra:*` (e.g., `infra:deploy:host:<host>`, `infra:logs:host:<host>`, `infra:rollback:host:<host>`).
- AI-specific validation/evidence/promote/status flows stay under `services:*` (`services:validate:host:*`, `services:evidence:*`, `services:promote:*`, `services:status:*`).
- Fleet checks such as `checks:fleet` and `checks:nullclaw:smoke:*` verify behavior after the canonical lifecycle commands run.

## Manifest-aware helpers
The helper script lists hosts, services, readable paths, validation/promote tasks, and the canonical `infra` or `services` task names you need for a host (`deploy-task`, `logs-task`, `validate-task`, `promote-task`). Use `task agents:hosts:tasks:<host>` to see the derived names from the shell.

## Promotion groups
The manifest exposes `promotionGroup` and `hostClass`. The group defines who appears in `services:promote:canary` vs `services:promote:class:*`; `hostClass` helps you reason about wrappers vs direct hosts.

## Host exceptions
When a host has operational nuance beyond the manifest, consult `.agents/deploy/hosts/<host>.md` before making assumptions. Otherwise, the manifest + helper + canonical tasks redirect all work.

## What not to assume
- Do not duplicate the manifest contents into `.agents/*`; point agents to the manifest or the helper script instead.
- Do not treat `.agents/*` as a second runtime truth—only the Taskfiles execute workflows.
