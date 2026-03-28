# Deploy Routing

## Scope
Operator deploy activity means: `infra:*` for host lifecycle flows and `services:*` for the AI validation/evidence/promotion surface described under `.agents/deploy/ai-hosts.md`.

## Entry points
- `taskfiles/infra.yml` (`infra:*`) runs rebuilds, switches, boots, deploys, and logs.
- `taskfiles/services-ai-hosts.yml` (`services:*`) runs the AI host flows.
- Manifest truth lives in `taskfiles/ai-host-manifest.json`; query it through `scripts/task/ai-host-manifest.sh` or the `agents:hosts:*` wrappers.

## AI host exceptions
Host-specific quirks live under `.agents/deploy/ai-hosts.md` plus per-host `.agents/deploy/hosts/*.md` notes.

## Guardrails
- `.agents/*` documents routing only; Taskfiles are the executable truth.
- Avoid duplicating the manifest.
