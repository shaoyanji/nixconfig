# mtfuji Exceptions

## Scope
Operational differences for `mtfuji` in AI host flows.

## Key Differences
- Host class `wrapper`, promotion group `stable`.
- Nullclaw mode `env-file`.
- Exposure type indicates no public nginx fronting for nullclaw policy path.

## Operational Interpretation
- Use standard host deploy flow (`services:deploy:host:mtfuji`).
- Promotion uses stable-group behavior unless explicitly targeted.
- Validation mapping is manifest-driven (`checks:nullclaw:smoke:mtfuji`).

## Source References
- `taskfiles/ai-host-manifest.json`
- `taskfiles/services-core.yml`
- `taskfiles/services-ai-hosts.yml`

## Manifest helper
Use `scripts/task/ai-host-manifest.sh show mtfuji` and `task agents:hosts:tasks:mtfuji` when you need the canonical commands or manifest values for this host.
