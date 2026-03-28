# Promotion Routing

## Scope
AI host promotion/readiness workflow routing.

## Source Of Truth
- Promotion/evidence/drift/status tasks: `taskfiles/services-ai-hosts.yml`
- Fleet checks: `taskfiles/checks.yml`
- Host metadata and promotion grouping: `taskfiles/ai-host-manifest.json`

## Canonical Task Surface
- Promote one host: `services:promote:host:*`
- Promote canary batch: `services:promote:canary`
- Promote class batch: `services:promote:class:*`
- Finalize receipt/baseline update: `services:promote:finalize:host:*`
- Readiness/status: `services:status:promotion-readiness`, `services:status:ai-hosts`, `services:status:delta:host:*`

## Flow Summary
- Run `checks:fleet`.
- Capture validation evidence.
- Run drift audit.
- Finalize promotion receipt/baseline.
- Use readiness/status tasks for operator review.

## What Not To Assume
- Do not bypass manifest-driven grouping for canary/class flows.
- Do not duplicate promotion policy in `.agents/*`; taskfiles + manifest remain authoritative.
