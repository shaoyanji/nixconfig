# AI Host Deployment

## Scope
Routing guidance for AI host deploy, validation, evidence, drift, and promotion flows.

## Source Of Truth
- Operator metadata: `taskfiles/ai-host-manifest.json`
- Execution tasks: `taskfiles/services-core.yml`, `taskfiles/services-ai-hosts.yml`, `taskfiles/checks.yml`
- Script implementation: `scripts/task/ai-host-*.sh`

## Canonical Task Surface
- Plan/apply/validate host: `services:plan:host:*`, `services:apply:host:*`, `services:validate:host:*`
- Deploy wrapper: `services:deploy:host:*`
- Evidence/drift/status: `services:evidence:*`, `services:drift:*`, `services:status:*`
- Promotion: `services:promote:host:*`, `services:promote:canary`, `services:promote:class:*`
- Fleet checks: `checks:fleet`

## Promotion Groups
Promotion group and host class are read from `taskfiles/ai-host-manifest.json`:
- `promotionGroup` drives canary/stable fan-out tasks.
- `hostClass` supports class-based batch operations.

## When To Read What
- Need host list or validation task mapping: read manifest.
- Need command flow or orchestration order: read taskfiles.
- Need command implementation details: read scripts.
- Need host nuance not obvious from manifest: read `.agents/deploy/hosts/*.md`.

## What Not To Assume
- Do not hardcode AI host lists outside manifest-backed flows.
- Do not infer execution behavior from `.agents/*`; tasks remain authoritative.
