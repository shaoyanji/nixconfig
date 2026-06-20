# Deploy Routing

## Scope
Operator deploy activity means `infra:*` for host lifecycle flows.

## Entry points
- `taskfiles/infra.yml` (`infra:*`) runs rebuilds, switches, boots, deploys, and logs.

## AI host exceptions
Per-host notes live under `.agents/deploy/hosts/*.md`.

## Guardrails
- `.agents/*` documents routing only; Taskfiles are the executable truth.
- Avoid duplicating the manifest.
