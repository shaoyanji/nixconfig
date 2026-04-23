# Promotion Routing

## Scope
Route readiness, promotion, and evidence work for AI hosts to the existing `services:*` flows and manifest-assisted grouping.

## Canonical tasks
- Promote one host: `services:promote:host:*`.
- Promotion batches: `services:promote:canary` and `services:promote:class:*` (manifest-driven grouping).
- Finalize receipt/baseline: `services:promote:finalize:host:*`.
- Readiness/status review: `services:status:promotion-readiness`, `services:status:ai-hosts`, `services:status:delta:host:*`.

## Helper guidance

## Manifest guidance
