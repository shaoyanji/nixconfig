# garnixMachine Exceptions

## Scope
Operational differences for `garnixMachine` in AI host flows.

## Key Differences
- Host class `wrapper`, promotion group `canary`.
- Nullclaw mode `config-json` with config staging path expectations.
- Exposure includes public nginx + bountystash shape.

## Operational Interpretation
- Use standard host deploy flow (`services:deploy:host:garnixMachine`) when targeting this host directly.
- Canary batch promotion/drift tasks include this host by manifest grouping.
- Validation mapping is manifest-driven (`checks:nullclaw:smoke:garnixMachine`).

## Source References
- `taskfiles/ai-host-manifest.json`
- `taskfiles/services-core.yml`
- `taskfiles/services-ai-hosts.yml`

## Manifest helper
Use `scripts/task/ai-host-manifest.sh show garnixMachine` and `task agents:hosts:tasks:garnixMachine` when you need the canonical commands or manifest values for this host.
