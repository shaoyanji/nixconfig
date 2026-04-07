# thinsandy Exceptions

## Scope
Operational differences for `thinsandy` relative to wrapper-style AI hosts.

## Key Differences
- Host class is `direct` (not wrapper).
- Service mix includes `nullclaw`, `openclaw-gateway`, and `hermes-agent`.
- Deployment style is direct AI services + nullclaw.

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:thinsandy`) for apply/validate (`services:deploy:host:thinsandy` remains a compatibility alias).
- Promotion/drift/evidence still run through shared AI host task surfaces.
- Validation mapping is manifest-driven (`checks:nullclaw:smoke:thinsandy`).

## Source References
- `taskfiles/ai-host-manifest.json`
- `taskfiles/services-core.yml`
- `taskfiles/services-ai-hosts.yml`

## Manifest helper
Use `scripts/task/ai-host-manifest.sh show thinsandy` and `task agents:hosts:tasks:thinsandy` when you need the canonical commands or manifest values for this host.
