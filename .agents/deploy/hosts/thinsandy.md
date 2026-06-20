# thinsandy Exceptions

## Scope
Operational differences for `thinsandy` relative to wrapper-style AI hosts.

## Key Differences
- Host class is `direct` (not wrapper).
- Service mix includes `nullclaw`, `openclaw-gateway`, and `hermes-agent`.
- Deployment style is direct AI services + nullclaw.

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:thinsandy`) for apply/validate (`services:deploy:host:thinsandy` remains a compatibility alias).
- Validation mapping is manifest-driven (`checks:nullclaw:smoke:thinsandy`).

## Source References
- `taskfiles/services-core.yml`

## Manifest helper
