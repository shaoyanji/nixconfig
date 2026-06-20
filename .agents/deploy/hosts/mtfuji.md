# mtfuji Exceptions

## Scope
Operational differences for `mtfuji` in AI host flows.

## Key Differences
- Nullclaw mode `env-file`.
- Exposure type indicates no public nginx fronting for nullclaw policy path.

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:mtfuji`) (`services:deploy:host:mtfuji` remains a compatibility alias).
- Validation mapping is manifest-driven (`checks:nullclaw:smoke:mtfuji`).

## Source References
- `taskfiles/services-core.yml`

## Manifest helper
