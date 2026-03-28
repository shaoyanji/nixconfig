# Promotion Routing

## Scope
Route readiness, promotion, and evidence work for AI hosts to the existing `services:*` flows and manifest-assisted grouping.

## Canonical tasks
- Promote one host: `services:promote:host:*`.
- Promotion batches: `services:promote:canary` and `services:promote:class:*` (manifest-driven grouping).
- Finalize receipt/baseline: `services:promote:finalize:host:*`.
- Readiness/status review: `services:status:promotion-readiness`, `services:status:ai-hosts`, `services:status:delta:host:*`.

## Helper guidance
Use `scripts/task/ai-host-manifest.sh promotion-group <host>` or `task agents:hosts:tasks:<host>` to understand which batch a host belongs to and the canonical promote task names.

## Manifest guidance
Promotion groups and host classes live in `taskfiles/ai-host-manifest.json`. Do not duplicate or copy these into `.agents/*`; point people to the manifest or the helper instead.
